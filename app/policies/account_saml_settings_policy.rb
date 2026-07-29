# Autorização das configurações de SAML SSO: só administradores. Reconstruído em MIT.
class AccountSamlSettingsPolicy < ApplicationPolicy
  def show?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end
end
