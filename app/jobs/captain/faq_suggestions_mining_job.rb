# Agenda a mineração de FAQs. Sem argumento: varre todos os assistentes (cron diário).
# Com assistant_id: minera só aquele (disparo manual/sob demanda). Cada conta sem hook
# openai configurado é no-op (o service verifica). Roda na fila scheduled_jobs.
class Captain::FaqSuggestionsMiningJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(assistant_id = nil)
    if assistant_id.present?
      mine(Captain::Assistant.find_by(id: assistant_id))
    else
      Captain::Assistant.find_each { |assistant| mine(assistant) }
    end
  end

  private

  def mine(assistant)
    return if assistant.nil?
    return unless assistant.account.feature_enabled?('captain_integration')

    Captain::FaqMiningService.new(assistant: assistant).perform
  rescue StandardError => e
    Rails.logger.warn("[captain-faq-mining] assistant=#{assistant&.id} falhou: #{e.message}")
  end
end
