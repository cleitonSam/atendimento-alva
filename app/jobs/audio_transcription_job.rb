# Transcrição de áudio — job próprio (MIT). Enfileirado quando um anexo de áudio é
# criado e a conta ligou o setting `audio_transcriptions`. Ver AudioTranscriptionService.
class AudioTranscriptionJob < ApplicationJob
  queue_as :low

  def perform(attachment_id)
    attachment = Attachment.find_by(id: attachment_id)
    return unless attachment

    AudioTranscriptionService.new(attachment: attachment).perform
  end
end
