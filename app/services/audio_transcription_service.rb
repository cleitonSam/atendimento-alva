# Transcrição de áudio — implementação própria (MIT), feita do zero no core.
# Usa a integração OpenAI (app_id 'openai') que já existe no Community Edition e o
# setting de conta `audio_transcriptions`. NÃO depende de nada em enterprise/.
#
# Fluxo: baixa o anexo de áudio, envia pro endpoint de transcrição da OpenAI (Whisper),
# grava o texto em attachment.meta['transcribed_text'] (que o serializer OSS já expõe
# como `transcribedText` pro front) e dispara message.updated pra UI atualizar sozinha.
class AudioTranscriptionService
  # Limite da API da OpenAI para o endpoint de transcrição (25 MB).
  MAX_AUDIO_BYTES = 25 * 1024 * 1024
  MODEL = 'whisper-1'.freeze

  def initialize(attachment:)
    @attachment = attachment
  end

  def perform
    return unless transcribable?

    text = request_transcription
    return if text.blank?

    persist(text)
    broadcast
    text
  end

  private

  attr_reader :attachment

  def transcribable?
    attachment.audio? &&
      ActiveModel::Type::Boolean.new.cast(account&.audio_transcriptions) &&
      api_key.present? &&
      attachment.file.attached? &&
      attachment.file.byte_size <= MAX_AUDIO_BYTES
  end

  def account
    @account ||= attachment.account
  end

  def api_key
    @api_key ||= account.hooks.find_by(app_id: 'openai', status: 'enabled')&.settings&.dig('api_key')
  end

  def endpoint
    base = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence || 'https://api.openai.com/'
    "#{base.chomp('/')}/v1/audio/transcriptions"
  end

  def request_transcription
    with_audio_tempfile do |tempfile|
      response = connection.post(endpoint) do |req|
        req.headers['Authorization'] = "Bearer #{api_key}"
        req.body = {
          model: MODEL,
          file: Faraday::Multipart::FilePart.new(tempfile, attachment.file.content_type, attachment.file.filename.to_s)
        }
      end
      next unless response.success?

      JSON.parse(response.body)['text'].to_s.strip
    end
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.warn("[audio-transcription] attachment=#{attachment.id} #{e.class}: #{e.message}")
    nil
  end

  def with_audio_tempfile
    tempfile = Tempfile.new(['audio-transcription', File.extname(attachment.file.filename.to_s)])
    tempfile.binmode
    tempfile.write(attachment.file.download)
    tempfile.rewind
    yield(tempfile)
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def connection
    Faraday.new do |f|
      f.request :multipart
      f.options.timeout = 120
      f.adapter Faraday.default_adapter
    end
  end

  def persist(text)
    attachment.update!(meta: (attachment.meta || {}).merge('transcribed_text' => text))
  end

  def broadcast
    return unless attachment.message

    Rails.configuration.dispatcher.dispatch(Events::Types::MESSAGE_UPDATED, Time.zone.now, message: attachment.message)
  end
end
