class CompanyPolicy < ApplicationPolicy
  def index?
    true
  end

  def search?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def destroy?
    @account_user.administrator?
  end

  def avatar?
    true
  end

  def destroy_custom_attributes?
    true
  end
end
