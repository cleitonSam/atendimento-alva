# Motor da automacao comentario->DM: dado um comentario recem-ingerido, acha a automacao
# ativa que casa (post + palavra-chave + janela), e envia a DM (comment-to-DM, com botao
# se tiver link) e/ou a resposta publica. Idempotente por usuario (once_per_user).
# Chamado em background por Instagram::CommentAutomationJob apos o CommentBuilder.
class Instagram::CommentAutomationService
  GRAPH_BASE = 'https://graph.instagram.com/v22.0'.freeze

  def initialize(message)
    @message = message
    @conversation = message.conversation
    @inbox = @conversation.inbox
    @channel = @inbox.channel
    @attrs = message.content_attributes || {}
  end

  def perform
    return unless applicable?

    automation = matching_automation
    return if automation.nil?

    dispatch(automation)
  rescue StandardError => e
    Rails.logger.error "[IG-AUTO] falhou (msg #{@message&.id}): #{e.class}: #{e.message}"
  end

  private

  def applicable?
    @attrs['is_instagram_comment'].present? && comment_id.present? && access_token.present?
  end

  def dispatch(automation)
    # Reserva o usuario ANTES de enviar (atomico) -> nada de DM dupla em corrida.
    return unless automation.claim_dispatch!(commenter_id)

    dm_result = send_dm(automation)
    reply_result = automation.public_reply.present? ? send_public_reply(automation) : nil

    if dm_result[:ok] || reply_result&.dig(:ok)
      automation.count_sent!
      record_activity(automation, dm_result, reply_result)
    else
      # falhou tudo -> libera a reserva pra um retry poder tentar de novo
      automation.unclaim_dispatch!(commenter_id)
    end
  end

  def comment_id
    @attrs['instagram_comment_id'].to_s
  end

  def media_id
    @attrs['instagram_media_id'].to_s
  end

  # source_id do contact_inbox do comentario = id do usuario do Instagram (setado no CommentBuilder).
  def commenter_id
    @conversation.contact_inbox&.source_id.to_s
  end

  def access_token
    @channel.try(:access_token)
  end

  def matching_automation
    @inbox.account.instagram_comment_automations
          .enabled.where(inbox_id: @inbox.id).to_a
          .find { |a| a.within_window? && a.applies_to_media?(media_id) && a.matches?(@message.content) }
  end

  def send_dm(automation)
    ig_id = @channel.try(:instagram_id).presence || 'me'
    response = HTTParty.post(
      "#{GRAPH_BASE}/#{ig_id}/messages",
      query: { access_token: access_token },
      body: { recipient: { comment_id: comment_id }, message: dm_payload(automation) }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    log('dm', response) unless response.success?
    { ok: response.success?, code: response.code }
  end

  # Com link -> template de botao (web_url); sem link -> texto puro.
  def dm_payload(automation)
    return { text: automation.dm_message } if automation.dm_link.blank?

    {
      attachment: {
        type: 'template',
        payload: {
          template_type: 'button',
          text: automation.dm_message,
          buttons: [{ type: 'web_url', url: automation.dm_link, title: automation.dm_button_label.presence || 'Abrir' }]
        }
      }
    }
  end

  def send_public_reply(automation)
    response = HTTParty.post(
      "#{GRAPH_BASE}/#{comment_id}/replies",
      query: { access_token: access_token },
      body: { message: automation.public_reply }
    )
    log('reply', response) unless response.success?
    { ok: response.success?, code: response.code }
  end

  def record_activity(automation, dm_result, reply_result)
    parts = []
    parts << 'DM automática' if dm_result[:ok]
    parts << 'resposta pública' if reply_result&.dig(:ok)
    return if parts.empty?

    @conversation.messages.create!(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :activity,
      content: "🤖 Automação \"#{automation.name}\": #{parts.join(' + ')}."
    )
  rescue StandardError => e
    Rails.logger.warn "[IG-AUTO] atividade falhou: #{e.message}"
  end

  def log(kind, response)
    Rails.logger.error "[IG-AUTO] #{kind} HTTP #{response.code}: #{response.body.to_s[0, 200]}"
  end
end
