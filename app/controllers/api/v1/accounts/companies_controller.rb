class Api::V1::Accounts::CompaniesController < Api::V1::Accounts::BaseController
  RESULTS_PER_PAGE = 15

  before_action :check_authorization
  before_action :fetch_company, only: [:show, :update, :destroy, :avatar, :destroy_custom_attributes]

  def index
    @companies = scope.order(name: :asc).page(current_page).per(RESULTS_PER_PAGE)
    @companies_count = scope.count
  end

  def search
    @companies = scope
                 .where('companies.name ILIKE :q OR companies.domain ILIKE :q', q: "%#{params[:q]}%")
                 .order(name: :asc).page(current_page).per(RESULTS_PER_PAGE)
    @companies_count = @companies.total_count
    render :index
  end

  def show; end

  def create
    @company = scope.create!(company_params)
    render :show
  end

  def update
    @company.update!(company_params)
    render :show
  end

  def destroy
    @company.destroy!
    head :ok
  end

  def avatar
    @company.avatar.purge if @company.avatar.attached?
    render :show
  end

  def destroy_custom_attributes
    @company.update!(custom_attributes: @company.custom_attributes.except(*params[:custom_attributes]))
    render :show
  end

  private

  def scope
    Current.account.companies
  end

  def fetch_company
    @company = scope.find(params[:id])
  end

  def current_page
    params[:page] || 1
  end

  def check_authorization
    authorize(Company)
  end

  def company_params
    params.require(:company).permit(
      :name, :domain, :description,
      additional_attributes: {}, custom_attributes: {}
    )
  end
end
