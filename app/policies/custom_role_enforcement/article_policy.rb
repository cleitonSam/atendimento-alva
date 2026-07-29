# Enforcement de cargos personalizados (MIT) — prepended em ArticlePolicy.
# Libera a base de conhecimento (artigos) para quem tem knowledge_base_manage.
module CustomRoleEnforcement
  module ArticlePolicy
    def index?
      custom_role_permits?('knowledge_base_manage') || super
    end

    def update?
      custom_role_permits?('knowledge_base_manage') || super
    end

    def show?
      custom_role_permits?('knowledge_base_manage') || super
    end

    def edit?
      custom_role_permits?('knowledge_base_manage') || super
    end

    def create?
      custom_role_permits?('knowledge_base_manage') || super
    end

    def destroy?
      custom_role_permits?('knowledge_base_manage') || super
    end

    def reorder?
      custom_role_permits?('knowledge_base_manage') || super
    end
  end
end
