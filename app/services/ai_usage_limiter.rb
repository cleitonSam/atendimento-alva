# Limitador de uso de IA por conta: teto por minuto e por dia (controle de CUSTO).
# É segurança de custo/abuso, NÃO de autorização — e NÃO afeta a mensagem do cliente
# (só pula o extra de IA: transcrição/sugestão). Se o Redis falhar, libera (fail-open).
# Limites via ENV (0 = sem limite):
#   AI_RATE_LIMIT_PER_MINUTE (padrão 20) · AI_RATE_LIMIT_PER_DAY (padrão 1000)
class AiUsageLimiter
  def self.allow?(account_id, kind)
    return true if account_id.blank?

    per_minute = ENV.fetch('AI_RATE_LIMIT_PER_MINUTE', '20').to_i
    per_day = ENV.fetch('AI_RATE_LIMIT_PER_DAY', '1000').to_i
    return true if per_minute <= 0 && per_day <= 0

    minute = bump("ai_usage:#{kind}:min:#{account_id}", 1.minute.to_i)
    day = bump("ai_usage:#{kind}:day:#{account_id}", 1.day.to_i)

    (per_minute <= 0 || minute <= per_minute) && (per_day <= 0 || day <= per_day)
  rescue StandardError
    true # Redis indisponível -> libera (é limite de custo, não boundary de segurança)
  end

  def self.bump(key, ttl_seconds)
    Redis::Alfred.incr(key).tap do |count|
      Redis::Alfred.expire(key, ttl_seconds) if count == 1
    end
  end
end
