# Enforcement de cargos personalizados (MIT) — prepended em PortalPolicy.
# Libera edição do portal/base de conhecimento para quem tem knowledge_base_manage.
module CustomRoleEnforcement
  module PortalPolicy
    def update?
      custom_role_permits?('knowledge_base_manage') || super
    end

    def edit?
      custom_role_permits?('knowledge_base_manage') || super
    end

    def logo?
      custom_role_permits?('knowledge_base_manage') || super
    end
  end
end
