# SAML SSO — provider OmniAuth multi-tenant (config dinâmica por conta).
# Reconstruído em MIT após a remoção da pasta enterprise/.

# Setup proc: configura a estratégia SAML em runtime a partir das settings da conta.
SAML_SETUP_PROC = proc do |env|
  request = ActionDispatch::Request.new(env)

  account_id = request.params['account_id'] ||
               env['omniauth.params']&.dig('account_id')
  relay_state = request.params['RelayState'] || ''

  if account_id
    # Mantém o contexto do request SAML no env do OmniAuth para o callback ser
    # processado sem depender do cookie de sessão do Rails.
    env['omniauth.params'] ||= {}
    env['omniauth.params']['account_id'] = account_id
    env['omniauth.params']['RelayState'] = relay_state

    settings = AccountSamlSettings.find_by(account_id: account_id)

    if settings
      env['omniauth.strategy'].options[:idp_sso_service_url_runtime_params] = { RelayState: :RelayState }
      env['omniauth.strategy'].options[:assertion_consumer_service_url] = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/omniauth/saml/callback?account_id=#{account_id}"
      env['omniauth.strategy'].options[:sp_entity_id] = settings.sp_entity_id
      env['omniauth.strategy'].options[:idp_entity_id] = settings.idp_entity_id
      env['omniauth.strategy'].options[:idp_sso_service_url] = settings.sso_url
      env['omniauth.strategy'].options[:idp_cert] = settings.certificate
      env['omniauth.strategy'].options[:name_identifier_format] = 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'
    else
      # Certificado dummy para evitar erro quando não há settings
      env['omniauth.strategy'].options[:idp_cert] = 'DUMMY'
    end
  else
    env['omniauth.strategy'].options[:idp_cert] = 'DUMMY'
  end
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :saml, setup: SAML_SETUP_PROC
end
