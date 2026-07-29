# Conversas dos contatos de uma empresa (sub-recurso de Companies) — código próprio (MIT).
class Api::V1::Accounts::Companies::ConversationsController < Api::V1::Accounts::BaseController
  before_action :fetch_company

  def index
    @conversations = Current.account.conversations
                            .where(contact_id: @company.contacts.select(:id))
                            .order(last_activity_at: :desc).page(params[:page] || 1).per(15)
  end

  private

  def fetch_company
    @company = Current.account.companies.find(params[:company_id])
  end
end
