class InstagramCommentAutomationPolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def show?
    index?
  end

  def create?
    index?
  end

  def update?
    create?
  end

  def destroy?
    create?
  end
end
