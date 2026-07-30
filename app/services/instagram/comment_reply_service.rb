# Posta a resposta de um comentario do Instagram na Graph API (Instagram API with
# Instagram login). A Alva (IA) gera o texto e chama a rota instagram_comment_reply;
# aqui a gente posta com o token da conta:
#   - public_reply -> POST /{comment_id}/replies      (resposta publica no comentario)
#   - dm_reply     -> POST /{ig_id}/messages          (private reply = comment-to-DM)
# Registra uma ATIVIDADE na conversa do comentario (visibilidade pro atendente) sem
# disparar envio de saida (nao vira DM acidental).
class Instagram::CommentReplyService
  GRAPH_BASE = 'https://graph.instagram.com/v22.0'.freeze

  def initialize(conversation:, comment_id:, public_reply: nil, dm_reply: nil)
    @conversation = conversation
    @channel = conversation.inbox.channel
    @comment_id = comment_id.to_s
    @public_reply = public_reply.to_s.presence
    @dm_reply = dm_reply.to_s.presence
  end

  def perform
    return { error: 'sem_comment_id' } if @comment_id.blank?
    return { error: 'canal_sem_token' } if access_token.blank?

    result = {}
    result[:public] = send_public_reply if @public_reply
    result[:dm] = send_private_reply if @dm_reply
    record_activity(result)
    result
  end

  private

  def access_token
    @access_token ||= @channel.try(:access_token)
  end

  def send_public_reply
    response = HTTParty.post(
      "#{GRAPH_BASE}/#{@comment_id}/replies",
      query: { access_token: access_token },
      body: { message: @public_reply }
    )
    log_failure('public', response) unless response.success?
    { ok: response.success?, code: response.code }
  end

  def send_private_reply
    ig_id = @channel.try(:instagram_id).presence || 'me'
    response = HTTParty.post(
      "#{GRAPH_BASE}/#{ig_id}/messages",
      query: { access_token: access_token },
      body: { recipient: { comment_id: @comment_id }, message: { text: @dm_reply } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    log_failure('private', response) unless response.success?
    { ok: response.success?, code: response.code }
  end

  # Atividade (message_type activity) — visivel, mas NUNCA re-enviada como mensagem.
  def record_activity(result)
    parts = []
    parts << 'respondeu o comentário publicamente' if @public_reply && result.dig(:public, :ok)
    parts << 'respondeu na DM (comment-to-DM)' if @dm_reply && result.dig(:dm, :ok)
    return if parts.empty?

    @conversation.messages.create!(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :activity,
      content: "🤖 Alva #{parts.join(' e ')}."
    )
  rescue StandardError => e
    Rails.logger.warn "[IG-COMMENT] registrar atividade falhou: #{e.message}"
  end

  def log_failure(kind, response)
    Rails.logger.error "[IG-COMMENT] reply #{kind} falhou HTTP #{response.code}: #{response.body.to_s[0, 200]}"
  end
end
