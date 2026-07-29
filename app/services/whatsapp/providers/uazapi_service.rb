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
  def create_instance(name)
    body = { name: name.to_s.parameterize.presence || "alva-#{SecureRandom.hex(4)}" }
    response = admin_post('/instance/init', body) || {}
    instance = response['instance'] || response
    { token: instance['token'] || response['token'], name: instance['name'], status: instance['status'], raw: response }
  end

  # Aponta a instancia para o nosso webhook receber tudo (mensagens + status).
  def register_webhook(callback_url)
    post('/webhook', {
           url: callback_url,
           events: %w[messages messages_update connection presence],
           enabled: true,
           excludeMessages: %w[wasSentByApi]
         })
  end

  # Inicia a conexao e retorna o QR code (data URL) para parear o numero.
  def connect(phone: nil)
    body = phone.present? ? { phone: phone.gsub(/\D/, '') } : {}
    response = post('/instance/connect', body)
    instance = response.is_a?(Hash) ? (response['instance'] || response) : {}
    { status: instance['status'], qrcode: instance['qrcode'] || response['qrcode'] }
  end

  # Estado atual: disconnected | connecting | connected | hibernated.
  def connection_status
    response = get('/instance/status')
    instance = response.is_a?(Hash) ? (response['instance'] || response) : {}
    { status: instance['status'], connected: instance['status'] == 'connected', qrcode: instance['qrcode'] }
  end

  def disconnect
    post('/instance/disconnect', {})
  end

  # ---- acoes de conversa (usadas pelos recursos premium) ----

  def mark_read(message_ids, chat_phone)
    post('/message/markread', { id: Array(message_ids), number: chat_phone.to_s.gsub(/\D/, '') })
  end

  def send_typing(phone, state = 'composing')
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

  # ---- envio ----

  def send_text_message(phone_number, message)
    body = {
      number: phone_number.to_s.gsub(/\D/, ''),
      text: message.outgoing_content.to_s,
      track_source: 'chatwoot'
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
      track_source: 'chatwoot'
    }
    process_uazapi_response(post('/send/media', body), message)
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
