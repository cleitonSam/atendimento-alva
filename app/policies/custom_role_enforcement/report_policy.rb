# Enforcement de cargos personalizados (MIT) — prepended em ReportPolicy.
# Libera a visualização de relatórios para quem tem report_manage.
module CustomRoleEnforcement
  module ReportPolicy
    def view?
      custom_role_permits?('report_manage') || super
    end
  end
end
