# Processa os eventos do webhook UAZAPI: mensagem recebida -> vira conversa no
# Chatwoot; atualizacao de status (ack) -> marca ✓✓/lido na bolha (premium).
class Webhooks::UazapiEventsJob < ApplicationJob
  queue_as :low

  # ack da UAZAPI (Baileys): 1 pending, 2 sent, 3 delivered, 4 read, 5 played
  ACK_TO_STATUS = { 3 => :delivered, 4 => :read, 5 => :read }.freeze
  STATUS_RANK = { 'sent' => 1, 'delivered' => 2, 'read' => 3 }.freeze

  def perform(params)
    params = params.with_indifferent_access
    channel = Channel::Whatsapp.find_by(phone_number: params[:phone_number])
    return if channel.nil? || channel.provider != 'uazapi'

    inbox = channel.inbox
    return if inbox.nil?

    if status_update?(params)
      update_message_status(inbox, params)
    else
      Whatsapp::IncomingMessageUazapiService.new(inbox: inbox, params: params).perform
    end
  end

  private

  # E uma atualizacao de status se o evento indica update/ack e NAO traz texto novo.
  def status_update?(params)
    event = (params[:event] || params[:type]).to_s
    return true if event.match?(/update|ack|status/i)

    node = message_node(params)
    node.present? && node[:ack].present? && node.dig(:message).blank?
  end

  def message_node(params)
    node = params[:message] || params[:data]
    node = params[:messages].first if node.blank? && params[:messages].is_a?(Array)
    (node || {}).with_indifferent_access
  end

  def update_message_status(inbox, params)
    node = message_node(params)
    source_id = (node.dig(:key, :id) || node[:id] || node[:messageid]).to_s
    ack = node[:ack] || node[:status]
    new_status = ACK_TO_STATUS[ack.to_i]
    return if source_id.blank? || new_status.nil?

    message = inbox.messages.find_by(source_id: source_id)
    return if message.nil? || message.status == 'failed'
    return if STATUS_RANK[new_status.to_s].to_i <= STATUS_RANK[message.status.to_s].to_i # nao regride

    message.update!(status: new_status)
  end
end
