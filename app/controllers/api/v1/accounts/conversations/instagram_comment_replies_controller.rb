# Rota que a Alva (IA) chama pra postar a resposta de um comentario do Instagram na
# Meta: POST /api/v1/accounts/:account_id/conversations/:conversation_id/instagram_comment_reply
# Body: { comment_id, mode, public_reply, dm_reply } — a IA gera o texto; o Chatwoot
# posta com o token da conta (reply publico e/ou comment-to-DM).
class Api::V1::Accounts::Conversations::InstagramCommentRepliesController < Api::V1::Accounts::Conversations::BaseController
  def create
    result = Instagram::CommentReplyService.new(
      conversation: @conversation,
      comment_id: params[:comment_id],
      public_reply: params[:public_reply],
      dm_reply: params[:dm_reply]
    ).perform

    if result[:error]
      render json: { success: false, error: result[:error] }, status: :unprocessable_entity
    else
      render json: { success: true, result: result }
    end
  end
end
