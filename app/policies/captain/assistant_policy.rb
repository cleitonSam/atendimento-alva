class Captain::AssistantPolicy < ApplicationPolicy
  def index?
    permitted?
  end

  def show?
    permitted?
  end

  def create?
    permitted?
  end

  def update?
    permitted?
  end

  def destroy?
    permitted?
  end

  private

  def permitted?
    account_user&.administrator? || custom_role_permits?('knowledge_base_manage')
  end
end
