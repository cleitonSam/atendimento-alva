# Sobe uma imagem (base64 ou URL) pro ImageKit e devolve a URL publica — a Meta baixa
# as imagens do carrossel por URL. Auth = Basic com a PRIVATE KEY (so no ENV).
class Imagekit::UploadService
  UPLOAD_URL = 'https://upload.imagekit.io/api/v1/files/upload'.freeze

  def initialize(file:, file_name:)
    @file = file
    @file_name = file_name
  end

  def perform
    return { error: 'imagekit_nao_configurado' } if private_key.blank?
    return { error: 'sem_arquivo' } if @file.blank?

    response = HTTParty.post(
      UPLOAD_URL,
      basic_auth: { username: private_key, password: '' },
      body: { file: normalized_file, fileName: @file_name.presence || 'upload.jpg', useUniqueFileName: 'true' }
    )
    return { url: response.parsed_response['url'], file_id: response.parsed_response['fileId'] } if response.success?

    Rails.logger.error "[IMAGEKIT] upload falhou HTTP #{response.code}: #{response.body.to_s[0, 200]}"
    { error: "imagekit_#{response.code}" }
  rescue StandardError => e
    Rails.logger.error "[IMAGEKIT] upload erro: #{e.class}: #{e.message}"
    { error: 'imagekit_erro' }
  end

  private

  def private_key
    ENV.fetch('IMAGEKIT_PRIVATE_KEY', '')
  end

  # Aceita data URL (data:image/...;base64,XXXX), base64 puro ou uma URL remota.
  def normalized_file
    @file.to_s.sub(/\Adata:[^;]+;base64,/, '')
  end
end
