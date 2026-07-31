# Publica uma InstagramScheduledPost na Content Publishing API (Instagram API with
# Instagram login). Imagem unica -> 1 container + publish. Carrossel -> 1 item container
# por imagem (is_carousel_item) + 1 container CAROUSEL(children) + publish. Espera o
# container ficar FINISHED antes de publicar; ao final marca published/failed + permalink.
class Instagram::PublishPostService
  GRAPH_BASE = 'https://graph.instagram.com/v22.0'.freeze
  STATUS_MAX_TRIES = 8
  STATUS_INTERVAL = 2 # segundos entre checagens do container

  def initialize(post)
    @post = post
    @channel = post.inbox.channel
  end

  def perform
    return @post.mark_failed!('canal sem token') if access_token.blank?
    return @post.mark_failed!('sem imagens') if @post.image_urls.blank?

    media_id = create_and_publish
    if media_id.present?
      @post.mark_published!(media_id, fetch_permalink(media_id))
      create_pending_automation(media_id)
      cleanup_imagekit
    else
      @post.mark_failed!(@error || 'falha ao publicar')
    end
  rescue StandardError => e
    Rails.logger.error "[IG-PUBLISH] post #{@post.id}: #{e.class}: #{e.message}"
    @post.mark_failed!("#{e.class}: #{e.message}")
  end

  private

  # Publicou -> o Instagram ja hospeda a propria copia, entao apaga do ImageKit pra
  # economizar storage e limpa image_urls/file_ids (nao ha mais thumbnail nem o que
  # re-deletar no destroy). So no sucesso; se falhar, mantem as imagens pro retry.
  def cleanup_imagekit
    file_ids = @post.image_file_ids
    Imagekit::DeleteFilesJob.perform_later(file_ids) if file_ids.present?
    @post.update_columns(image_urls: [], image_file_ids: []) # rubocop:disable Rails/SkipsModelValidations
  end

  # Unifica publicar + automatizar: se o post trouxe uma automacao pendente, cria a
  # InstagramCommentAutomation JA com o media_id publicado (sem o usuario colar id).
  def create_pending_automation(media_id)
    cfg = @post.pending_automation
    return if cfg.blank?

    @post.account.instagram_comment_automations.create!(
      inbox: @post.inbox,
      media_id: media_id,
      name: cfg['name'].presence || "Automação #{media_id}",
      keywords: cfg['keywords'],
      match_type: cfg['match_type'].presence || 'contains',
      dm_message: cfg['dm_message'],
      dm_link: cfg['dm_link'],
      dm_button_label: cfg['dm_button_label'],
      public_reply: cfg['public_reply'],
      once_per_user: cfg.fetch('once_per_user', true),
      enabled: true
    )
  rescue StandardError => e
    Rails.logger.error "[IG-PUBLISH] criar automacao pendente falhou (post #{@post.id}): #{e.message}"
  end

  def create_and_publish
    creation_id = @post.carousel? ? build_carousel : build_single
    return nil if creation_id.blank?
    return nil unless wait_until_ready(creation_id)

    publish(creation_id)
  end

  def ig_id
    @channel.try(:instagram_id).presence || 'me'
  end

  def access_token
    @channel.try(:access_token)
  end

  def build_single
    create_container(image_url: @post.image_urls.first, caption: @post.caption)
  end

  def build_carousel
    children = @post.image_urls.map { |url| create_container(image_url: url, is_carousel_item: true) }
    return nil if children.any?(&:blank?)

    create_container(media_type: 'CAROUSEL', caption: @post.caption, children: children.join(','))
  end

  # POST /{ig_id}/media -> devolve o id do container (creation_id)
  def create_container(params)
    response = post("#{GRAPH_BASE}/#{ig_id}/media", params)
    return capture_error(response) unless response.success?

    response.parsed_response['id']
  end

  def wait_until_ready(creation_id)
    STATUS_MAX_TRIES.times do
      status = container_status(creation_id)
      return true if status == 'FINISHED'
      break if %w[ERROR EXPIRED].include?(status)

      sleep STATUS_INTERVAL
    end
    @error ||= 'container nao ficou FINISHED'
    false
  end

  def container_status(creation_id)
    response = HTTParty.get("#{GRAPH_BASE}/#{creation_id}", query: { fields: 'status_code', access_token: access_token })
    response.success? ? response.parsed_response['status_code'] : nil
  end

  # POST /{ig_id}/media_publish -> devolve o media_id publicado
  def publish(creation_id)
    response = post("#{GRAPH_BASE}/#{ig_id}/media_publish", creation_id: creation_id)
    return capture_error(response) unless response.success?

    response.parsed_response['id']
  end

  def fetch_permalink(media_id)
    response = HTTParty.get("#{GRAPH_BASE}/#{media_id}", query: { fields: 'permalink', access_token: access_token })
    response.success? ? response.parsed_response['permalink'] : nil
  rescue StandardError
    nil
  end

  def post(url, params)
    HTTParty.post(url, query: { access_token: access_token }, body: params)
  end

  def capture_error(response)
    parsed = response.parsed_response
    parsed = {} unless parsed.is_a?(Hash)
    @error = [parsed.dig('error', 'code'), parsed.dig('error', 'message')].compact.join(' - ').presence ||
             "HTTP #{response.code}"
    Rails.logger.error "[IG-PUBLISH] #{@error}"
    nil
  end
end
