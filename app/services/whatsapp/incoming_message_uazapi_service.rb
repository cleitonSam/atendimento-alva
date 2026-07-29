# Transforma o webhook da UAZAPI (formato Baileys) em contato + conversa + mensagem
# no Chatwoot. Proprio e defensivo (as chaves do payload variam por versao/evento);
# nao herda o base da Meta. Foco: mensagem de texto recebida (midia = proximo passo).
class Whatsapp::IncomingMessageUazapiService
  pattr_initialize [:inbox!, :params!]

  def perform
    return if sender_phone.blank?
    return if from_me? # eco do proprio numero -> ignora (nao duplica o que o painel enviou)
    return if message_id.blank?

    set_contact
    return if @contact_inbox.blank?

    set_conversation
    create_message
  end

  private

  # A msg pode vir em 'message', 'data', ou no primeiro item de 'messages'.
  def event_message
    @event_message ||= begin
      msg = params['message'] || params['data']
      msg = params['messages'].first if msg.blank? && params['messages'].is_a?(Array)
      (msg || {}).with_indifferent_access
    end
  end

  def key
    (event_message['key'] || {}).with_indifferent_access
  end

  def sender_phone
    jid = key['remoteJid'] || event_message['chatid'] || event_message['number'] || event_message['sender']
    jid.to_s.split('@').first.to_s.gsub(/\D/, '').presence
  end

  def from_me?
    key['fromMe'] == true || event_message['fromMe'] == true
  end

  def push_name
    event_message['pushName'] || event_message['senderName'] || event_message['notifyName']
  end

  def message_id
    (key['id'] || event_message['id'] || event_message['messageid']).to_s.presence
  end

  def text_content
    inner = (event_message['message'] || {}).with_indifferent_access
    inner['conversation'].presence ||
      inner.dig('extendedTextMessage', 'text').presence ||
      event_message['text'].presence ||
      event_message['body'].presence ||
      event_message['content'].presence
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
    return if text_content.blank? # midia sera tratada num proximo incremento
    return if @conversation.messages.exists?(source_id: message_id) # dedup de webhook

    @conversation.messages.create!(
      content: text_content,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: message_id
    )
  end
end
