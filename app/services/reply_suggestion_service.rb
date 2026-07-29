# Sugestão de resposta com IA (Captain-lite) — implementação própria (MIT).
# Usa a integração OpenAI do Community (hook app_id 'openai') pra sugerir ao agente
# uma resposta baseada no histórico da conversa. NÃO depende de nada em enterprise/.
class ReplySuggestionService
  DEFAULT_MODEL = 'gpt-4o-mini'.freeze
  MAX_CONTEXT_MESSAGES = 12

  def initialize(conversation:, draft: nil)
    @conversation = conversation
    @draft = draft.presence
  end

  # Retorna { reply: '...' } em sucesso ou { error: '<motivo>' }.
  def perform
    return { error: 'openai_not_configured' } if api_key.blank?

    reply = request_suggestion
    return { error: 'no_suggestion' } if reply.blank?

    { reply: reply }
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.warn("[ai-reply] conversation=#{@conversation.id} #{e.class}: #{e.message}")
    { error: 'request_failed' }
  end

  private

  def account
    @conversation.account
  end

  def api_key
    @api_key ||= account.hooks.find_by(app_id: 'openai', status: 'enabled')&.settings&.dig('api_key')
  end

  def model
    InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence || DEFAULT_MODEL
  end

  def endpoint
    base = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence || 'https://api.openai.com/'
    "#{base.chomp('/')}/v1/chat/completions"
  end

  def request_suggestion
    response = connection.post(endpoint) do |req|
      req.headers['Authorization'] = "Bearer #{api_key}"
      req.headers['Content-Type'] = 'application/json'
      req.body = { model: model, temperature: 0.4, messages: prompt_messages }.to_json
    end
    return unless response.success?

    JSON.parse(response.body).dig('choices', 0, 'message', 'content').to_s.strip
  end

  def prompt_messages
    messages = [{ role: 'system', content: system_prompt }] + history_messages
    messages << { role: 'user', content: "Rascunho do agente para melhorar:\n#{@draft}" } if @draft
    messages
  end

  def system_prompt
    if @draft
      <<~PROMPT.squish
        Você melhora rascunhos de resposta de um agente de atendimento. Reescreva o rascunho
        com clareza, correção gramatical e um tom cordial e profissional, MANTENDO o sentido e
        o MESMO idioma. Responda apenas com o texto melhorado, sem aspas nem prefixos.
      PROMPT
    else
      <<~PROMPT.squish
        Você é um agente de atendimento ao cliente prestativo e cordial. Escreva UMA resposta
        curta, natural e no MESMO idioma do cliente para a última mensagem dele. Não invente
        informações que você não tem. Não repita saudações se a conversa já começou. Responda
        apenas com o texto da mensagem, sem aspas nem prefixos.
      PROMPT
    end
  end

  # Últimas mensagens (entrada/saída, públicas, com conteúdo), em ordem cronológica.
  def history_messages
    @conversation.messages
                 .reorder(created_at: :desc)
                 .limit(40)
                 .to_a
                 .select { |m| (m.incoming? || m.outgoing?) && !m.private? && m.content.present? }
                 .first(MAX_CONTEXT_MESSAGES)
                 .reverse
                 .map { |m| { role: m.incoming? ? 'user' : 'assistant', content: m.content.to_s } }
  end

  def connection
    Faraday.new do |f|
      f.options.timeout = 60
      f.adapter Faraday.default_adapter
    end
  end
end
