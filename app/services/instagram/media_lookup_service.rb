# Busca os detalhes da MIDIA (o post) que a pessoa comentou, pela Graph API. Reels/video
# devolvem thumbnail_url em vez de media_url -> pedimos os dois. O link media_url da Meta
# e temporario, entao cacheamos por pouco tempo.
#
# Dois modos:
#  - new(conversation:)        -> le media_id + token da conversa e cacheia NELA
#                                 (additional_attributes). Usado na conversa do comentario.
#  - new(channel:, media_id:)  -> explicito; cacheia no Redis por media_id. Usado na tela
#                                 post-centrica, onde 1 conversa pode ter comentarios de
#                                 VARIOS posts (o CommentBuilder reusa a conversa por contato).
class Instagram::MediaLookupService
  GRAPH_BASE = 'https://graph.instagram.com/v22.0'.freeze
  FIELDS = 'id,media_url,permalink,caption,media_type,thumbnail_url'.freeze
  CACHE_TTL = 30.minutes

  def initialize(conversation: nil, channel: nil, media_id: nil)
    @conversation = conversation
    @channel = channel || conversation&.inbox&.channel
    @explicit_media_id = media_id
  end

  def perform
    return cached_result if fresh_cache?
    return cached_result || {} if media_id.blank? || access_token.blank?

    fetch_and_store || cached_result || {}
  rescue StandardError => e
    Rails.logger.warn "[IG-POST] lookup do post comentado falhou (#{log_context}): #{e.message}"
    cached_result || {}
  end

  private

  def fetch_and_store
    data = fetch
    return if data.blank?

    result = {
      'image_url' => data['media_url'].presence || data['thumbnail_url'],
      'permalink' => data['permalink'],
      'caption' => data['caption'],
      'media_type' => data['media_type']
    }.compact
    store(result)
    result
  end

  def media_id
    @explicit_media_id.presence || @conversation&.additional_attributes&.dig('instagram_comment_post_id')
  end

  def access_token
    @channel.try(:access_token)
  end

  def fetch
    response = HTTParty.get(
      "#{GRAPH_BASE}/#{media_id}",
      query: { fields: FIELDS, access_token: access_token }
    )
    response.success? ? response.parsed_response : nil
  end

  # ---- cache: na conversa (modo A) ou no Redis por media_id (modo B) ----
  def cached_result
    if @conversation
      @conversation.additional_attributes&.dig('instagram_commented_post')
    else
      raw = ::Redis::Alfred.get(redis_key)
      raw.present? ? JSON.parse(raw) : nil
    end
  end

  def fresh_cache?
    if @conversation
      stamp = cached_result&.dig('fetched_at')
      stamp.present? && Time.zone.parse(stamp.to_s) > CACHE_TTL.ago
    else
      cached_result.present? # o TTL do Redis ja controla a validade
    end
  rescue StandardError
    false
  end

  def store(result)
    if @conversation
      @conversation.update!(
        additional_attributes: @conversation.additional_attributes.merge(
          'instagram_commented_post' => result.merge('fetched_at' => Time.current.iso8601)
        )
      )
    else
      ::Redis::Alfred.setex(redis_key, result.to_json, CACHE_TTL)
    end
  end

  def redis_key
    "ig_media_lookup:#{media_id}"
  end

  def log_context
    @conversation ? "conv #{@conversation.id}" : "media #{media_id}"
  end
end
