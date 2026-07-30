# Devolve o POST (imagem/permalink/legenda) que originou o comentario, pra UI mostrar
# a publicacao dentro da conversa do comentario do Instagram.
# GET /api/v1/accounts/:account_id/conversations/:conversation_id/instagram_commented_post
class Api::V1::Accounts::Conversations::InstagramCommentedPostsController < Api::V1::Accounts::Conversations::BaseController
  def show
    render json: Instagram::MediaLookupService.new(conversation: @conversation).perform
  end
end
