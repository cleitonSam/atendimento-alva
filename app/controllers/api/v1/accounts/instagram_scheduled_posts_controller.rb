# Publicacoes do Instagram (imagem/carrossel) + agendamento.
# /api/v1/accounts/:account_id/instagram_scheduled_posts
#   POST .../upload  -> sobe uma imagem pro ImageKit e devolve a URL publica
class Api::V1::Accounts::InstagramScheduledPostsController < Api::V1::Accounts::BaseController
  before_action :set_post, only: [:destroy]
  before_action :check_authorization

  def index
    render json: posts.order(created_at: :desc)
  end

  def create
    post = posts.new(post_params.merge(status: 'scheduled'))
    post.save!
    # publica ja se nao tem data ou ja venceu; futuro fica pra varredura cron.
    Instagram::PublishInstagramPostJob.perform_later(post.id) if publish_now?(post)
    render json: post
  end

  def destroy
    @post.destroy!
    head :ok
  end

  # Assinatura pro upload CLIENT-SIDE do ImageKit (o navegador sobe a imagem direto;
  # nao passa o base64 gigante pelo nosso backend).
  def imagekit_auth
    result = Imagekit::AuthService.new.perform
    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: result
    end
  end

  private

  # check_authorization padrao constantiza InstagramScheduledPost -> policy propria.

  def posts
    Current.account.instagram_scheduled_posts
  end

  def set_post
    @post = posts.find(params[:id])
  end

  def publish_now?(post)
    post.scheduled_at.blank? || post.scheduled_at <= Time.current
  end

  def post_params
    params.require(:instagram_scheduled_post).permit(:inbox_id, :caption, :scheduled_at, image_urls: [])
  end
end
