# Contatos de uma empresa (sub-recurso de Companies) — código próprio (MIT).
class Api::V1::Accounts::Companies::ContactsController < Api::V1::Accounts::BaseController
  before_action :fetch_company

  def index
    @contacts = @company.contacts.order(name: :asc).page(page).per(15)
    @contacts_count = @company.contacts.count
  end

  def search
    @contacts = @company.contacts
                        .where('contacts.name ILIKE :q OR contacts.email ILIKE :q', q: "%#{params[:q]}%")
                        .order(name: :asc).page(page).per(15)
    @contacts_count = @contacts.total_count
    render :index
  end

  def create
    contact = Current.account.contacts.find(params[:contact_id])
    contact.update!(company: @company)
    head :ok
  end

  def destroy
    contact = @company.contacts.find(params[:id])
    contact.update!(company: nil)
    head :ok
  end

  private

  def fetch_company
    @company = Current.account.companies.find(params[:company_id])
  end

  def page
    params[:page] || 1
  end
end
