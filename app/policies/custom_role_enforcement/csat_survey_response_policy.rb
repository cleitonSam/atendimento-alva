# Enforcement de cargos personalizados (MIT) — prepended em CsatSurveyResponsePolicy.
# Libera métricas/CSAT para quem tem report_manage.
module CustomRoleEnforcement
  module CsatSurveyResponsePolicy
    def index?
      custom_role_permits?('report_manage') || super
    end

    def metrics?
      custom_role_permits?('report_manage') || super
    end

    def download?
      custom_role_permits?('report_manage') || super
    end

    def update?
      account_user.administrator? || custom_role_permits?('report_manage')
    end
  end
end
