# Fluxo de conexao do provider UAZAPI (aditivo): provisiona a instancia com o
# admin token, aponta o webhook pra ca e gera o QR; o front faz polling do status.
# Nao toca em nada do whatsapp_cloud oficial.
class Api::V1::Accounts::UazapiChannelsController < Api::V1::Accounts::BaseController
  before_action :fetch_channel
  before_action :authorize_admin

  # POST: garante a instancia (cria se ainda nao houver token), registra o webhook
  # e inicia a conexao — devolvendo o QR pra escanear.
  def setup
    provision_instance_if_needed
    register_webhook
    result = provider.connect
    render json: { status: result[:status], qrcode: result[:qrcode] }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET: status atual da conexao (disconnected/connecting/connected). Ao conectar,
  # (re)registra o webhook por garantia.
  def status
    result = provider.connection_status
    register_webhook if result[:connected]
    render json: result
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_channel
    @inbox = Current.account.inboxes.find(params[:id])
    @channel = @inbox.channel
    return if @channel.is_a?(Channel::Whatsapp) && @channel.provider == 'uazapi'

    render json: { error: 'Esta caixa não é UAZAPI' }, status: :unprocessable_entity
  end

  def authorize_admin
    render json: { error: 'Apenas administradores' }, status: :forbidden unless Current.account_user&.administrator?
  end

  def provider
    @channel.provider_service
  end

  # Sem token de instancia ainda -> cria uma no servidor UAZAPI (admin token) e guarda.
  def provision_instance_if_needed
    return if @channel.provider_config['api_token'].present?

    result = provider.create_instance(@channel.provider_config['instance_name'].presence || @inbox.name)
    raise 'Falha ao criar a instância na UAZAPI (confira URL e admin token)' if result[:token].blank?

    @channel.update!(provider_config: @channel.provider_config.merge('api_token' => result[:token]))
  end

  def register_webhook
    base = ENV.fetch('FRONTEND_URL', nil).presence || request.base_url
    provider.register_webhook("#{base}/webhooks/uazapi/#{@channel.phone_number}")
  rescue StandardError => e
    Rails.logger.warn "[UAZAPI] register_webhook falhou: #{e.message}"
  end
end
