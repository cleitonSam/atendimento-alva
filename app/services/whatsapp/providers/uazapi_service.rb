# Provider UAZAPI (WhatsApp nao-oficial) — ADITIVO ao canal WhatsApp, ao lado de
# whatsapp_cloud (Meta oficial) e default (360dialog), sem tocar em nenhum deles.
# Fala com a API atual UAZAPI v2.1.1 (/send/*, /instance/*), auth por header 'token'
# (instancia) ou 'admintoken' (admin do servidor). Endpoints herdados de versoes
# antigas (/message/send, /chat/completions) NAO sao usados.
class Whatsapp::Providers::UazapiService < Whatsapp::Providers::BaseService
  # Erro transitorio (timeout / 5xx / 429): o Sidekiq re-tenta o job de envio.
  class RetryableError < StandardError; end

  HTTP_OPEN_TIMEOUT = 5
  HTTP_READ_TIMEOUT = 20
  RETRYABLE_CODES = [429, 500, 502, 503, 504].freeze

  # ---- interface do provider (chamada por Whatsapp::SendOnWhatsappService) ----

  def send_message(phone_number, message)
    @message = message
    return send_pix(phone_number, message) if pix_payload(message).present?

    if message.attachments.present?
      send_attachment_message(phone_number, message)
    else
      send_text_message(phone_number, message)
    end
  end

  # UAZAPI nao usa templates aprovados pela Meta; um "template" vira texto simples.
  def send_template(phone_number, _template_info, message)
    send_text_message(phone_number, message)
  end

  # Sem catalogo de templates na UAZAPI.
  def sync_templates
    whatsapp_channel.mark_message_templates_updated
  end

  # UAZAPI nao usa templates aprovados pela Meta -> o CSAT (e afins) vai por LINK
  # (texto com a URL da pesquisa), nao por template. Retorna 'nao aprovado' para o
  # CsatSurveyService cair no fluxo generico em vez do template Meta.
  def get_template_status(_template_name)
    { success: false, template: { status: 'NOT_APPLICABLE' } }
  end

  # No momento da criacao da caixa ainda NAO ha token de instancia (ele nasce no
  # init/QR). Entao aqui validamos so que da pra alcancar o servidor: precisa da
  # URL e de pelo menos um token (admin para provisionar, ou o da instancia se ja
  # existe). A conexao real acontece no fluxo de QR.
  def validate_provider_config?
    api_url.present? && (admin_token.present? || api_token.present?)
  end

  def api_headers
    { 'token' => api_token, 'Content-Type' => 'application/json' }
  end

  # ---- ciclo de vida da instancia (QR / conexao) ----

  # Cria a instancia no servidor (admintoken). Devolve o token da instancia, que
  # passa a ser usado em todas as chamadas por-numero (envio, status, connect).
  # v2.1.1: endpoint /instance/create; o token vem em 'token' (top-level).
  def create_instance(name)
    body = { name: name.to_s.parameterize.presence || "alva-#{SecureRandom.hex(4)}" }
    response = admin_post('/instance/create', body) || {}
    instance = response['instance'] || {}
    { token: response['token'] || instance['token'], name: instance['name'], status: instance['status'], raw: response }
  end

  # Aponta a instancia para o nosso webhook receber tudo (mensagens + status).
  # events validos v2.1.1: connection, messages, messages_update, presence, ...
  def register_webhook(callback_url)
    post('/webhook', {
           url: callback_url,
           events: %w[messages messages_update connection],
           enabled: true,
           excludeMessages: %w[wasSentByApi]
         })
  end

  # Inicia a conexao e retorna o QR (base64) para parear. Se passar phone, a UAZAPI
  # devolve paircode (codigo de pareamento) em vez de QR.
  def connect(phone: nil)
    body = phone.present? ? { phone: phone.gsub(/\D/, '') } : {}
    response = post('/instance/connect', body) || {}
    { status: extract_status(response), qrcode: response['qrcode'], paircode: response['paircode'] }
  end

  # Estado atual: disconnected | connecting | connected | hibernated.
  def connection_status
    response = get('/instance/status') || {}
    status = extract_status(response)
    { status: status, connected: connected?(response, status), qrcode: response['qrcode'] }
  end

  def disconnect
    post('/instance/disconnect', {})
  end

  # Delay global (em segundos) entre envios no servidor — pacing anti-ban.
  def update_delay_settings(min_seconds, max_seconds)
    post('/instance/updateDelaySettings', { msg_delay_min: min_seconds.to_i, msg_delay_max: max_seconds.to_i })
  end

  # ---- acoes de conversa (usadas pelos recursos premium) ----

  # v2.1.1: body {chatid, id}. chatid pode ser o numero ou o jid completo.
  def mark_read(message_ids, chatid)
    post('/message/markread', { chatid: chatid.to_s, id: Array(message_ids) })
  end

  # v2.1.1: presence in typing | recording | paused (nao 'composing').
  def send_typing(phone, state = 'typing')
    post('/message/presence', { number: phone.to_s.gsub(/\D/, ''), presence: state })
  end

  def send_reaction(message_id, phone, emoji)
    post('/message/react', { id: message_id, number: phone.to_s.gsub(/\D/, ''), text: emoji })
  end

  # Detalhes do contato (foto, nome, business) — para enriquecer o atendimento.
  def contact_details(phone)
    post('/chat/details', { number: phone.to_s.gsub(/\D/, ''), preview: false })
  end

  # Valida quais numeros existem no WhatsApp (higiene de lista pre-disparo).
  def check_numbers(phones)
    post('/chat/check', { numbers: Array(phones).map { |p| p.to_s.gsub(/\D/, '') } })
  end

  # Transcreve uma nota de voz recebida (audio -> texto) via download?transcribe.
  def transcribe(message_id)
    response = post('/message/download', { id: message_id, transcribe: true, return_base64: false })
    response.is_a?(Hash) ? response['transcription'] : nil
  end

  private

  # ---- status da instancia ----

  # status como string enum: disconnected|connecting|connected|hibernated.
  def extract_status(response)
    return nil unless response.is_a?(Hash)

    instance_status = response.dig('instance', 'status')
    return instance_status if instance_status.present?

    response['status'].is_a?(String) ? response['status'] : nil
  end

  def connected?(response, status)
    return true if status == 'connected'

    response.is_a?(Hash) && response.dig('status', 'connected') == true
  end

  # ---- envio ----

  def send_text_message(phone_number, message)
    body = {
      number: phone_number.to_s.gsub(/\D/, ''),
      text: message.outgoing_content.to_s,
      track_source: 'chatwoot',
      async: true # enfileira no servidor (pacing anti-ban com o delay global)
    }
    reply_id = message.content_attributes&.dig('in_reply_to_external_id')
    body[:replyid] = reply_id if reply_id.present?

    process_uazapi_response(post('/send/text', body), message)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    body = {
      number: phone_number.to_s.gsub(/\D/, ''),
      type: uazapi_media_type(attachment.file_type),
      file: attachment.download_url,
      text: message.outgoing_content.to_s,
      track_source: 'chatwoot',
      async: true
    }
    process_uazapi_response(post('/send/media', body), message)
  end

  # Marcador que transforma uma mensagem em PIX/cobranca (em content_attributes,
  # sem precisar de content_type novo). Setado pela UI/automacao/API.
  def pix_payload(message)
    message.content_attributes&.dig('uazapi_pix')
  end

  # PIX/cobranca. request-payment (cartao com valor) se houver amount; senao botao PIX.
  def send_pix(phone_number, message)
    attrs = pix_payload(message).to_h.with_indifferent_access
    number = phone_number.to_s.gsub(/\D/, '')
    common = {
      pixKey: attrs[:pix_key], pixType: (attrs[:pix_type].presence || 'EVP'), pixName: attrs[:pix_name],
      track_source: 'chatwoot', async: true
    }
    response = if attrs[:amount].present?
                 post('/send/request-payment', {
                        number: number, amount: attrs[:amount].to_f,
                        title: attrs[:title].presence || 'Pagamento',
                        text: message.outgoing_content.to_s, itemName: attrs[:item_name],
                        invoiceNumber: attrs[:invoice_number]
                      }.merge(common))
               else
                 post('/send/pix-button', { number: number }.merge(common))
               end
    process_uazapi_response(response, message)
  end

  def uazapi_media_type(file_type)
    {
      'image' => 'image', 'video' => 'video', 'audio' => 'audio',
      'file' => 'document'
    }.fetch(file_type.to_s, 'document')
  end

  # A UAZAPI devolve o id da mensagem em messageId/id/data.messageId.
  def process_uazapi_response(response, message)
    return handle_uazapi_error(response, message) if response.blank? || response['error'].present?

    source_id = response['messageId'] || response['id'] ||
                response.dig('data', 'messageId') || response.dig('message', 'id')
    source_id.presence
  end

  def handle_uazapi_error(response, message)
    error = response.is_a?(Hash) ? (response['error'] || response['message']) : 'erro desconhecido'
    Rails.logger.error "[UAZAPI] envio falhou: #{error}"
    if message.present?
      message.external_error = error.to_s.truncate(500)
      message.status = :failed
      message.save!
    end
    nil
  end

  # ---- HTTP ----

  def base_domain
    url = api_url.to_s.strip.chomp('/')
    url.sub(%r{/instance/.*\z}, '')
  end

  def api_url
    whatsapp_channel.provider_config['api_url'].presence || ENV.fetch('UAZAPI_URL', nil)
  end

  def api_token
    whatsapp_channel.provider_config['api_token'].presence
  end

  def admin_token
    whatsapp_channel.provider_config['admin_token'].presence || ENV.fetch('UAZAPI_ADMIN_TOKEN', nil)
  end

  def admin_headers
    { 'admintoken' => admin_token, 'Content-Type' => 'application/json' }
  end

  def get(path)
    perform_request(:get, path, nil, api_headers)
  end

  def post(path, body)
    perform_request(:post, path, body, api_headers)
  end

  def admin_post(path, body)
    perform_request(:post, path, body, admin_headers)
  end

  def perform_request(method, path, body, headers)
    response = HTTParty.public_send(
      method,
      "#{base_domain}#{path}",
      headers: headers,
      body: body&.to_json,
      open_timeout: HTTP_OPEN_TIMEOUT,
      read_timeout: HTTP_READ_TIMEOUT
    )
    raise_if_retryable(response, path)
    response.parsed_response
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
    raise RetryableError, "UAZAPI #{path}: #{e.message}"
  end

  def raise_if_retryable(response, path)
    return unless RETRYABLE_CODES.include?(response.code)

    raise RetryableError, "UAZAPI #{path}: HTTP #{response.code}"
  end
end
