# Modera um comentario do Instagram pela Graph API (mesma conta/token do reply):
#   - delete -> DELETE /{comment_id}            (exclui o comentario no Instagram)
#   - hide   -> POST   /{comment_id}?hide=true  (oculta)
#   - unhide -> POST   /{comment_id}?hide=false (reexibe)
# Ao excluir, marca a mensagem local como deletada (some da tela e nao conta mais).
# Registra uma ATIVIDADE na conversa (visibilidade pro atendente), sem re-enviar nada.
class Instagram::CommentModerationService
  GRAPH_BASE = 'https://graph.instagram.com/v22.0'.freeze
  ACTIONS = %w[delete hide unhide].freeze

  def initialize(conversation:, comment_id:, action:)
    @conversation = conversation
    @channel = conversation.inbox.channel
    @comment_id = comment_id.to_s
    @action = action.to_s
  end

  def perform
    return { error: 'sem_comment_id' } if @comment_id.blank?
    return { error: 'acao_invalida' } unless ACTIONS.include?(@action)
    return { error: 'canal_sem_token' } if access_token.blank?

    @action == 'delete' ? delete_comment : apply_hidden(@action == 'hide')
  end

  private

  def access_token
    @access_token ||= @channel.try(:access_token)
  end

  def delete_comment
    response = HTTParty.delete("#{GRAPH_BASE}/#{@comment_id}", query: { access_token: access_token })
    if response.success?
      mark_local_deleted
      record_activity('Comentário excluído no Instagram.')
    else
      log_failure('delete', response)
    end
    { ok: response.success?, code: response.code }
  end

  def apply_hidden(hidden)
    response = HTTParty.post("#{GRAPH_BASE}/#{@comment_id}", query: { hide: hidden, access_token: access_token })
    if response.success?
      record_activity(hidden ? 'Comentário ocultado no Instagram.' : 'Comentário reexibido no Instagram.')
    else
      log_failure(hidden ? 'hide' : 'unhide', response)
    end
    { ok: response.success?, code: response.code }
  end

  # Marca a mensagem do comentario como deletada (soft), pra sumir da tela e da contagem.
  def mark_local_deleted
    @conversation.messages.find_by(source_id: @comment_id)&.update!(deleted: true)
  rescue StandardError => e
    Rails.logger.warn "[IG-COMMENT] marcar deletado local falhou: #{e.message}"
  end

  def record_activity(text)
    @conversation.messages.create!(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :activity,
      content: text
    )
  rescue StandardError => e
    Rails.logger.warn "[IG-COMMENT] atividade moderacao falhou: #{e.message}"
  end

  def log_failure(kind, response)
    Rails.logger.error "[IG-COMMENT] moderacao #{kind} falhou HTTP #{response.code}: #{response.body.to_s[0, 200]}"
  end
end
