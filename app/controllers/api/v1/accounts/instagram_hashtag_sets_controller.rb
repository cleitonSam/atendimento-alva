# CRUD dos conjuntos de hashtags reutilizaveis do Instagram.
# /api/v1/accounts/:account_id/instagram_hashtag_sets
class Api::V1::Accounts::InstagramHashtagSetsController < Api::V1::Accounts::BaseController
  before_action :set_hashtag_set, only: [:update, :destroy]
  before_action :check_authorization

  def index
    render json: hashtag_sets.order(:name)
  end

  def create
    render json: hashtag_sets.create!(hashtag_set_params)
  end

  def update
    @hashtag_set.update!(hashtag_set_params)
    render json: @hashtag_set
  end

  def destroy
    @hashtag_set.destroy!
    head :ok
  end

  private

  def hashtag_sets
    Current.account.instagram_hashtag_sets
  end

  def set_hashtag_set
    @hashtag_set = hashtag_sets.find(params[:id])
  end

  def hashtag_set_params
    params.require(:instagram_hashtag_set).permit(:name, :hashtags)
  end
end
