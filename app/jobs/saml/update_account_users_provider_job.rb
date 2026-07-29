# Atualiza o provider de autenticação dos usuários de uma conta quando o SAML é
# criado ('saml') ou removido ('email'). Ao voltar para 'email', preserva quem
# ainda usa SAML em outras contas. Reconstruído em MIT.
class Saml::UpdateAccountUsersProviderJob < ApplicationJob
  queue_as :default

  def perform(account_id, provider)
    account = Account.find(account_id)
    account.users.find_each(batch_size: 1000) do |user|
      next unless should_update_user_provider?(user, provider)

      # rubocop:disable Rails/SkipsModelValidations
      user.update_column(:provider, provider)
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  private

  def should_update_user_provider?(user, provider)
    return !user_has_other_saml_accounts?(user) if provider == 'email'

    true
  end

  def user_has_other_saml_accounts?(user)
    user.accounts.joins(:saml_settings).exists?
  end
end
