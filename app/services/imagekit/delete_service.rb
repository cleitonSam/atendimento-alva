# Deleta arquivos no ImageKit por fileId (gestao de midia, api.imagekit.io — Basic auth
# com a PRIVATE KEY, so no servidor). Usado ao excluir a publicacao pra nao deixar
# imagem orfa no ImageKit. Usa o bulk delete (1 chamada pra todas as imagens do post).
class Imagekit::DeleteService
  BULK_DELETE_URL = 'https://api.imagekit.io/v1/files/batch/deleteByFileIds'.freeze

  def initialize(file_ids:)
    @file_ids = Array(file_ids).map(&:to_s).reject(&:blank?).uniq
  end

  def perform
    return if @file_ids.blank? || private_key.blank?

    response = HTTParty.post(
      BULK_DELETE_URL,
      basic_auth: { username: private_key, password: '' },
      body: { fileIds: @file_ids }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    # 404 = algum fileId ja nao existe -> ok, o objetivo (nao deixar lixo) foi atingido.
    log_failure(response) unless response.success? || response.code == 404
    response.success?
  rescue StandardError => e
    Rails.logger.error "[IMAGEKIT-DEL] #{e.class}: #{e.message}"
    false
  end

  private

  def private_key
    ENV.fetch('IMAGEKIT_PRIVATE_KEY', '')
  end

  def log_failure(response)
    Rails.logger.error "[IMAGEKIT-DEL] falhou HTTP #{response.code}: #{response.body.to_s[0, 200]}"
  end
end
