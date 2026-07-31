# Roda a automacao comentario->DM em background (nao trava o webhook do comentario).
class Instagram::CommentAutomationJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    Instagram::CommentAutomationService.new(message).perform
  end
end
