# Ingere um COMENTARIO do Instagram (webhook field=comments/live_comments) como uma
# conversa PROPRIA, separada das conversas de DM — pra nao misturar. A conversa e
# marcada com additional_attributes.type = 'instagram_comment' e ganha a label
# 'comentario' (vira uma aba/pasta propria na sidebar). A mensagem carrega os
# content_attributes que a Alva (IA) consome pra responder (publico / comment-to-DM):
# is_instagram_comment + instagram_comment_id/media_id/media_product_type/parent_id.
class Instagram::CommentBuilder
  COMMENT_LABEL = 'comentario'.freeze

  # value = o hash `entry.changes[].value` do webhook de comentario do Instagram.
  def initialize(value, channel)
    @value = value.with_indifferent_access
    @channel = channel
    @inbox = channel.inbox
  end

  def perform
    return if comment_id.blank? || commenter_id.blank?
    return if own_comment? # comentario da propria conta -> nao responde a si mesma
    return if @inbox.channel.reauthorization_required?
    return if message_already_exists?

    ActiveRecord::Base.transaction do
      build_contact
      build_conversation
      build_message
    end
    # Automacao comentario->DM (palavra-chave -> DM automatica), em background.
    Instagram::CommentAutomationJob.perform_later(@message.id) if @message&.persisted?
    @message
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @inbox&.account).capture_exception
    nil
  end

  private

  def comment_id
    @value[:id].to_s.presence
  end

  def commenter
    @value[:from] || {}
  end

  def commenter_id
    commenter[:id].to_s.presence
  end

  def commenter_username
    commenter[:username].presence
  end

  def own_comment?
    commenter_id == @channel.instagram_id.to_s
  end

  def media
    @value[:media] || {}
  end

  def build_contact
    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      inbox: @inbox,
      source_id: commenter_id,
      contact_attributes: { name: commenter_username.presence || "Instagram #{commenter_id}" }
    ).perform
    @contact = @contact_inbox.contact
  end

  # Reusa a conversa de comentario ABERTA do contato (nao mistura com DM); senao cria.
  def build_conversation
    @conversation = @contact_inbox.conversations
                                  .where("additional_attributes ->> 'type' = ?", 'instagram_comment')
                                  .where.not(status: :resolved)
                                  .order(created_at: :desc).first
    @conversation ||= create_conversation
    apply_comment_label
  end

  def create_conversation
    Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: {
        type: 'instagram_comment',
        instagram_comment_post_id: media[:id]
      }
    )
  end

  # Garante a label 'comentario' (com cor) e aplica na conversa -> aba propria na sidebar.
  def apply_comment_label
    @inbox.account.labels.find_or_create_by!(title: COMMENT_LABEL) do |label|
      label.color = '#E1306C'
      label.show_on_sidebar = true
    end
    @conversation.add_labels([COMMENT_LABEL]) unless @conversation.label_list.include?(COMMENT_LABEL)
  end

  def build_message
    @message = @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      source_id: comment_id,
      sender: @contact,
      content: @value[:text].to_s,
      content_attributes: {
        is_instagram_comment: true,
        instagram_comment_id: comment_id,
        instagram_media_id: media[:id],
        instagram_media_product_type: media[:media_product_type],
        instagram_parent_comment_id: @value[:parent_id]
      }.compact
    )
  end

  def message_already_exists?
    @inbox.messages.exists?(source_id: comment_id)
  end
end
