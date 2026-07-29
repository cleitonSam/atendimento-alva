class Api::V1::Accounts::CustomRolesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_custom_role, only: [:show, :update, :destroy]

  def index
    @custom_roles = Current.account.custom_roles.order(created_at: :desc)
  end

  def show; end

  def create
    @custom_role = Current.account.custom_roles.create!(custom_role_params)
    render :show
  end

  def update
    @custom_role.update!(custom_role_params)
    render :show
  end

  def destroy
    @custom_role.destroy!
    head :ok
  end

  private

  def fetch_custom_role
    @custom_role = Current.account.custom_roles.find(params[:id])
  end

  def check_authorization
    authorize(CustomRole)
  end

  def custom_role_params
    params.require(:custom_role).permit(:name, :description, permissions: [])
  end
end
