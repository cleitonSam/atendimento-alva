# Modera um comentario do Instagram (o atendente aciona pela tela de Comentarios):
# POST /api/v1/accounts/:account_id/conversations/:conversation_id/instagram_comment_moderation
# Body: { comment_id, moderation } onde moderation e 'delete' | 'hide' | 'unhide'.
# (moderation, nao 'action' — este ultimo e reservado pelo Rails.)
class Api::V1::Accounts::Conversations::InstagramCommentModerationsController < Api::V1::Accounts::Conversations::BaseController
  def create
    result = Instagram::CommentModerationService.new(
      conversation: @conversation,
      comment_id: params[:comment_id],
      action: params[:moderation]
    ).perform

    if result[:ok]
      render json: { success: true, result: result }
    else
      render json: { success: false, error: result[:error] || "graph_#{result[:code]}" }, status: :unprocessable_entity
    end
  end
end
