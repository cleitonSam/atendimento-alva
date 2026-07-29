# Visualizador de logs de auditoria — código próprio (MIT). Lê a tabela `audits`
# (gem `audited`, OSS) associada à conta. A GRAVAÇÃO segue pelos concerns por ora
# (vira nossa quando o enterprise/ for removido). Substitui o controller enterprise.
class Api::V1::Accounts::AuditLogsController < Api::V1::Accounts::BaseController
  RESULTS_PER_PAGE = 25

  before_action :check_authorization

  def show
    @audit_logs = Current.account.associated_audits
                         .order(created_at: :desc)
                         .page(current_page).per(RESULTS_PER_PAGE)
    @audit_logs_count = Current.account.associated_audits.count
  end

  private

  def current_page
    params[:page] || 1
  end

  def check_authorization
    authorize(:audit_log, :show?)
  end
end
