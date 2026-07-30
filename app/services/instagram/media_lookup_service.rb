# Busca os detalhes da MIDIA (o post) que a pessoa comentou, pela Graph API, pra
# mostrar a publicacao dentro da conversa do comentario. Cacheia por pouco tempo em
# additional_attributes (o link media_url da Meta e temporario). Reels/video devolvem
# thumbnail_url em vez de media_url -> pedimos os dois.
class Instagram::MediaLookupService
  GRAPH_BASE = 'https://graph.instagram.com/v22.0'.freeze
  FIELDS = 'id,media_url,permalink,caption,media_type,thumbnail_url'.freeze
  CACHE_TTL = 30.minutes

  def initialize(conversation:)
    @conversation = conversation
    @channel = conversation.inbox.channel
  end

  def perform
    return cached if fresh_cache?
    return cached || {} if media_id.blank? || access_token.blank?

    data = fetch
    return cached || {} if data.blank?

    result = {
      'image_url' => data['media_url'].presence || data['thumbnail_url'],
      'permalink' => data['permalink'],
      'caption' => data['caption'],
      'media_type' => data['media_type']
    }.compact
    store(result)
    result
  rescue StandardError => e
    Rails.logger.warn "[IG-POST] lookup do post comentado falhou (conv #{@conversation.id}): #{e.message}"
    cached || {}
  end

  private

  def media_id
    @conversation.additional_attributes&.dig('instagram_comment_post_id')
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

  def cached
    @conversation.additional_attributes&.dig('instagram_commented_post')
  end

  def fresh_cache?
    stamp = cached&.dig('fetched_at')
    stamp.present? && Time.zone.parse(stamp.to_s) > CACHE_TTL.ago
  rescue StandardError
    false
  end

  def store(result)
    @conversation.update!(
      additional_attributes: @conversation.additional_attributes.merge(
        'instagram_commented_post' => result.merge('fetched_at' => Time.current.iso8601)
      )
    )
  end
end
