# Bloqueia login por SENHA de usuário SAML (MIT), prepended em
# DeviseOverrides::SessionsController. Usuário com provider 'saml' deve entrar
# pelo IdP, não por e-mail/senha.
module SamlSessionConcern
  include SamlAuthenticationHelper

  def create
    if saml_user_attempting_password_auth?(params[:email], sso_auth_token: params[:sso_auth_token])
      render json: {
        success: false,
        message: I18n.t('messages.login_saml_user'),
        errors: [I18n.t('messages.login_saml_user')]
      }, status: :unauthorized
      return
    end

    super
  end
end
