class Captain::FaqSuggestionPolicy < ApplicationPolicy
  def index?
    permitted?
  end

  def show?
    permitted?
  end

  def update?
    permitted?
  end

  def approve?
    permitted?
  end

  def dismiss?
    permitted?
  end

  private

  # Gestão de conhecimento: administrador ou cargo personalizado com knowledge_base_manage.
  def permitted?
    account_user&.administrator? || custom_role_permits?('knowledge_base_manage')
  end
end
