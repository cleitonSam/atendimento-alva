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
      return { ok: true, code: response.code }
    end

    # Objeto ja nao existe no Instagram (ex.: a pessoa apagou o comentario/post) -> some
    # da plataforma mesmo assim (e so o nosso cache); delete idempotente.
    if already_gone?(response)
      mark_local_deleted
      record_activity('Comentário removido (já não existe no Instagram).')
      return { ok: true, code: response.code, gone: true }
    end

    log_failure('delete', response)
    result_for(response)
  end

  # Erro 100 "... does not exist ..." = o objeto ja foi removido no Instagram.
  def already_gone?(response)
    parsed = response.parsed_response
    parsed = {} unless parsed.is_a?(Hash)
    parsed.dig('error', 'code') == 100 &&
      parsed.dig('error', 'message').to_s.downcase.include?('does not exist')
  rescue StandardError
    false
  end

  def apply_hidden(hidden)
    response = HTTParty.post("#{GRAPH_BASE}/#{@comment_id}", query: { hide: hidden, access_token: access_token })
    if response.success?
      record_activity(hidden ? 'Comentário ocultado no Instagram.' : 'Comentário reexibido no Instagram.')
    else
      log_failure(hidden ? 'hide' : 'unhide', response)
    end
    result_for(response)
  end

  def result_for(response)
    return { ok: true, code: response.code } if response.success?

    { ok: false, code: response.code, error: graph_error(response) }
  end

  # Mensagem legivel do erro da Graph (ex.: "10 - ... requires instagram_manage_comments").
  def graph_error(response)
    parsed = response.parsed_response
    parsed = {} unless parsed.is_a?(Hash)
    [parsed.dig('error', 'code'), parsed.dig('error', 'message')].compact.join(' - ').presence ||
      "HTTP #{response.code}"
  rescue StandardError
    "HTTP #{response.code}"
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
