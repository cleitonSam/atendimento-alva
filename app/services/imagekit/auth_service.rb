# Gera a assinatura pro upload CLIENT-SIDE do ImageKit (o navegador sobe a imagem
# direto pro ImageKit; nosso backend so assina, sem passar o arquivo por aqui).
# A PRIVATE KEY fica so no ENV; devolve public_key + token/expire/signature.
class Imagekit::AuthService
  UPLOAD_URL = 'https://upload.imagekit.io/api/v1/files/upload'.freeze
  TTL = 30.minutes # ImageKit aceita expire de ate 1h

  def perform
    return { error: 'imagekit_nao_configurado' } if private_key.blank?

    token = SecureRandom.uuid
    expire = Time.now.to_i + TTL.to_i
    {
      token: token,
      expire: expire,
      signature: OpenSSL::HMAC.hexdigest('SHA1', private_key, "#{token}#{expire}"),
      public_key: public_key,
      upload_url: UPLOAD_URL
    }
  end

  private

  def private_key
    ENV.fetch('IMAGEKIT_PRIVATE_KEY', '')
  end

  def public_key
    ENV.fetch('IMAGEKIT_PUBLIC_KEY', '')
  end
end
