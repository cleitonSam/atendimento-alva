# Enforcement de cargos personalizados (MIT) — prepended em ContactPolicy.
# Libera export/import de contatos para quem tem a permissão contact_manage.
module CustomRoleEnforcement
  module ContactPolicy
    def export?
      custom_role_permits?('contact_manage') || super
    end

    def import?
      custom_role_permits?('contact_manage') || super
    end
  end
end
