# Segurança SAML (MIT), prepended em AgentBuilder: ao criar um agente numa conta
# com SAML habilitado, marca o usuário como provider 'saml' para que ele entre
# pelo IdP (senão nasceria como 'email' e poderia burlar o SSO por senha/reset).
module SamlAgentBuilderConcern
  def perform
    super.tap do |user|
      convert_to_saml_provider(user) if user.persisted? && account.saml_enabled?
    end
  end

  private

  def convert_to_saml_provider(user)
    user.update!(provider: 'saml') unless user.provider == 'saml'
  end
end
