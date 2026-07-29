# Recebe o webhook da UAZAPI para uma caixa (identificada por phone_number na URL).
# Valida um token compartilhado antes de enfileirar. Aditivo — nao mexe no
# webhook oficial da Meta (Webhooks::WhatsappController).
class Webhooks::UazapiController < ActionController::API
  def process_payload
    channel = Channel::Whatsapp.find_by(phone_number: params[:phone_number])
    return head :not_found if channel.nil? || channel.provider != 'uazapi'
    return head :unauthorized unless valid_token?(channel)

    Webhooks::UazapiEventsJob.perform_later(params.to_unsafe_hash)
    head :ok
  end

  private

  def valid_token?(channel)
    expected = channel.provider_config['webhook_verify_token'].presence
    return true if expected.blank? # sem token configurado -> aceita (compat)

    provided = request.headers['X-Webhook-Token'].presence || params[:token].presence
    ActiveSupport::SecurityUtils.secure_compare(provided.to_s, expected.to_s) if provided.present?
  end
end
