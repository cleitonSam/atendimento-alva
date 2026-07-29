# Notas dos contatos de uma empresa (sub-recurso de Companies) — código próprio (MIT).
class Api::V1::Accounts::Companies::NotesController < Api::V1::Accounts::BaseController
  before_action :fetch_company

  def index
    @notes = Note.where(account_id: Current.account.id, contact_id: @company.contacts.select(:id))
                 .order(created_at: :desc)
  end

  private

  def fetch_company
    @company = Current.account.companies.find(params[:company_id])
  end
end
