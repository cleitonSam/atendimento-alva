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

  # Recebe uma imagem (base64/dataURL) e devolve a URL publica do ImageKit.
  def upload
    result = Imagekit::UploadService.new(file: params[:file], file_name: params[:file_name]).perform
    if result[:url].present?
      render json: { url: result[:url] }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
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
