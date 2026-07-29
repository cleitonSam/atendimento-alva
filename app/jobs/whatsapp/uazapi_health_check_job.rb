# Health-check das instancias UAZAPI (agendado). Para cada caixa uazapi:
# - conectada  -> cura (limpa flags + reauthorized!)
# - caida       -> tenta reconectar, guarda o QR novo e marca reauthorization (banner
#                  + e-mail pro admin re-escanear em 1 clique) — "traz o QR sozinho"
# - banida      -> marca banned + alerta forte (nao fica tentando reconectar)
# prompt_reauthorization! so alerta na TRANSICAO, entao rodar a cada ciclo nao gera spam.
class Whatsapp::UazapiHealthCheckJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::Whatsapp.where(provider: 'uazapi').find_each do |channel|
      check(channel)
    rescue StandardError => e
      Rails.logger.warn "[UAZAPI] health check falhou (inbox #{channel.inbox&.id}): #{e.message}"
    end
  end

  private

  def check(channel)
    return if channel.inbox.nil?

    provider = channel.provider_service
    status = provider.connection_status

    if status[:connected]
      heal(channel)
    elsif provider.banned?(status[:disconnect_reason])
      handle_ban(channel)
    else
      handle_disconnected(channel, provider)
    end
  end

  def heal(channel)
    dirty = channel.provider_config['reconnect_qr'].present? || channel.provider_config['banned']
    merge_config(channel, 'reconnect_qr' => nil, 'reconnect_qr_at' => nil, 'banned' => false) if dirty
    channel.reauthorized! if channel.reauthorization_required?
  end

  def handle_disconnected(channel, provider)
    qrcode = provider.connect[:qrcode]
    merge_config(channel, 'reconnect_qr' => qrcode, 'reconnect_qr_at' => Time.now.to_i, 'banned' => false)
    channel.prompt_reauthorization!
    Rails.logger.info "[UAZAPI] instancia caida — QR novo gerado (inbox #{channel.inbox.id})"
  end

  def handle_ban(channel)
    merge_config(channel, 'banned' => true, 'reconnect_qr' => nil)
    channel.prompt_reauthorization!
    Rails.logger.error "[UAZAPI] numero possivelmente BANIDO/BLOQUEADO — inbox #{channel.inbox.id} (#{channel.phone_number})"
  end

  # save!(validate: false): pula validate_provider_config (chamada de rede) ao persistir.
  def merge_config(channel, changes)
    channel.provider_config = channel.provider_config.merge(changes)
    channel.save!(validate: false)
  end
end
