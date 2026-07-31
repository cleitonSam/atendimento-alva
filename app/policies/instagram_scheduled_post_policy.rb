class InstagramScheduledPostPolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def show?
    index?
  end

  def create?
    index?
  end

  def destroy?
    create?
  end

  def imagekit_auth?
    create?
  end
end
