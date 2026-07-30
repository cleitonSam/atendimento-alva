require 'resolv'
require 'ipaddr'

# Transforma o webhook da UAZAPI (v2.1.1) em contato + conversa + mensagem no
# Chatwoot. Aditivo, proprio (nao herda o base da Meta). Trata TEXTO e MIDIA
# (imagem/video/audio/documento/figurinha), transcreve audio recebido e enriquece
# o contato com foto+nome do WhatsApp. Campos conforme o spec oficial:
# sender, messageid, fromMe, isGroup, text, messageType, content.url, fileURL.
class Whatsapp::IncomingMessageUazapiService
  pattr_initialize [:inbox!, :params!]

  MEDIA_TYPES = %w[image video audio ptt document sticker].freeze

  def perform
    return if from_me?           # eco do proprio numero
    return if group_message?     # grupos: opt-in futuro (F2)
    return if sender_phone.blank? || message_id.blank?

    set_contact
    return if @contact_inbox.blank?

    return if record_csat_if_rating # resposta do CSAT interativo (pode nao ter texto) -> grava e para
    return if text_content.blank? && media_url.blank?

    set_conversation
    create_message
    transcribe_audio
    enrich_contact
  end

  private

  # A msg pode vir em 'message'/'data', no primeiro de 'messages', ou com os campos
  # ja no topo do payload.
  def message_node
    @message_node ||= begin
      node = params['message'] || params['data']
      node = params['messages'].first if node.blank? && params['messages'].is_a?(Array)
      node = params if node.blank? && (params['messageid'] || params['sender']).present?
      (node || {}).with_indifferent_access
    end
  end

  def sender_phone
    jid = message_node['sender'] || message_node['chatid'] || message_node['number']
    jid.to_s.split('@').first.to_s.gsub(/\D/, '').presence
  end

  def from_me?
    message_node['fromMe'] == true
  end

  def group_message?
    message_node['isGroup'] == true || message_node['chatid'].to_s.include?('@g.us')
  end

  def push_name
    message_node['pushName'].presence || message_node['senderName'].presence
  end

  def message_id
    (message_node['messageid'] || message_node['id']).to_s.presence
  end

  def message_type
    message_node['messageType'].to_s
  end

  def text_content
    message_node['text'].presence ||
      message_node['caption'].presence ||
      message_node.dig('content', 'caption').presence
  end

  def media?
    MEDIA_TYPES.include?(message_type) || media_url.present?
  end

  def media_url
    message_node['fileURL'].presence || message_node.dig('content', 'url').presence
  end

  def media_content_type
    case message_type
    when 'image', 'sticker' then :image
    when 'audio', 'ptt' then :audio
    when 'video' then :video
    else :file
    end
  end

  # ---- CSAT interativo (resposta da lista) ----

  # Id selecionado na lista de CSAT: 'csat_1'..'csat_5'. Defensivo com o shape do
  # webhook (selectedRowId / listResponse / selectedButtonId / texto cru).
  def csat_rating
    id = message_node['selectedRowId'].presence ||
         message_node.dig('listResponse', 'singleSelectReply', 'selectedRowId') ||
         message_node.dig('content', 'selectedRowId') ||
         message_node['selectedButtonId'].presence ||
         message_node['text'].to_s.strip
    id.to_s[/\Acsat_([1-5])\z/, 1]&.to_i
  end

  def record_csat_if_rating
    rating = csat_rating
    return false if rating.nil?

    csat_msg = Message.where(conversation_id: @contact_inbox.conversations.select(:id), content_type: :input_csat)
                      .order(created_at: :desc).first
    return false if csat_msg.nil?
    # Idempotente/anti-replay: nao sobrescreve uma nota ja registrada.
    return true if csat_msg.content_attributes.dig('submitted_values', 'csat_survey_response', 'rating').present?

    csat_msg.update!(content_attributes: csat_msg.content_attributes.merge(
                       'submitted_values' => { 'csat_survey_response' => { 'rating' => rating } }
                     ))
    CsatSurveys::ResponseBuilder.new(message: csat_msg).perform
    true
  rescue StandardError => e
    Rails.logger.warn "[UAZAPI] gravar CSAT falhou: #{e.message}"
    false
  end

  def set_contact
    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      inbox: inbox,
      source_id: sender_phone,
      contact_attributes: { name: push_name.presence || sender_phone, phone_number: "+#{sender_phone}" }
    ).perform
    @contact = @contact_inbox&.contact
  end

  def set_conversation
    @conversation = @contact_inbox.conversations.where.not(status: :resolved).last
    @conversation ||= ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: { source: 'uazapi' }
    )
  end

  def create_message
    return if @conversation.messages.exists?(source_id: message_id) # dedup de webhook

    @message = @conversation.messages.build(
      content: text_content,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: message_id
    )
    attach_media if media?
    @message.save!
  end

  def attach_media
    file = download_media
    return if file.blank?

    @message.attachments.new(
      account_id: inbox.account_id,
      file_type: media_content_type,
      file: { io: file, filename: file.original_filename, content_type: file.content_type }
    )
  end

  PRIVATE_IP_RANGES = [
    IPAddr.new('0.0.0.0/8'), IPAddr.new('10.0.0.0/8'), IPAddr.new('127.0.0.0/8'),
    IPAddr.new('169.254.0.0/16'), IPAddr.new('172.16.0.0/12'), IPAddr.new('192.168.0.0/16'),
    IPAddr.new('::1/128'), IPAddr.new('fc00::/7'), IPAddr.new('fe80::/10')
  ].freeze

  # Baixa a midia com trava anti-SSRF: so http(s), host que NAO resolva para IP
  # privado/loopback/link-local (bloqueia 169.254.169.254, 127/10/172.16/192.168...),
  # com timeout e teto de tamanho (anti-DoS). A URL vem de payload de webhook.
  def download_media
    return unless safe_remote_url?(media_url)

    Down.download(media_url, headers: download_headers, max_size: 25 * 1024 * 1024,
                            open_timeout: 5, read_timeout: 20)
  rescue StandardError => e
    Rails.logger.warn "[UAZAPI] download de midia falhou (#{media_url}): #{e.message}"
    nil
  end

  def safe_remote_url?(url)
    uri = URI.parse(url.to_s)
    return false unless %w[http https].include?(uri.scheme) && uri.host.present?

    addresses = Resolv.getaddresses(uri.host)
    return false if addresses.empty?

    addresses.none? { |addr| private_ip?(addr) }
  rescue StandardError
    false
  end

  def private_ip?(addr)
    ip = IPAddr.new(addr)
    PRIVATE_IP_RANGES.any? { |range| range.include?(ip) }
  rescue StandardError
    true # nao parseou -> trata como inseguro
  end

  # A fileURL da UAZAPI costuma exigir o token da instancia.
  def download_headers
    token = inbox.channel.provider_config['api_token']
    token.present? ? { 'token' => token } : {}
  end

  # Nota de voz recebida -> texto (via /message/download?transcribe), best-effort.
  def transcribe_audio
    return unless @message&.persisted?
    return unless %w[audio ptt].include?(message_type)
    return if @message.content.present?

    text = inbox.channel.provider_service.transcribe(message_id)
    return if text.blank?

    @message.update!(content: text)
  rescue StandardError => e
    Rails.logger.warn "[UAZAPI] transcricao falhou: #{e.message}"
  end

  # Foto + nome real do WhatsApp — so na 1a vez (quando ainda nao tem avatar).
  def enrich_contact
    return if @contact.blank? || @contact.avatar.attached? || @contact.avatar_url.present?

    details = inbox.channel.provider_service.contact_details(sender_phone) || {}
    name = details['name'].presence
    pic = details['profilePicUrl'].presence

    @contact.update!(name: name) if name.present? && @contact.name == sender_phone
    Avatar::AvatarFromUrlJob.perform_later(@contact, pic) if pic.present?
  rescue StandardError => e
    Rails.logger.warn "[UAZAPI] enriquecimento de contato falhou: #{e.message}"
  end
end
