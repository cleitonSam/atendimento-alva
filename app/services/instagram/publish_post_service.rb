# Publica uma InstagramScheduledPost na Content Publishing API (Instagram API with
# Instagram login). Por formato:
#   - post imagem unica -> 1 container + publish
#   - post carrossel    -> 1 item container por imagem (is_carousel_item) + 1 container
#                          CAROUSEL(children) + publish
#   - reels             -> 1 container media_type=REELS(video_url) + publish
#   - story             -> 1 container media_type=STORIES(image_url|video_url) + publish
# Espera o container ficar FINISHED antes de publicar (video demora mais); ao final
# marca published/failed + permalink e limpa as midias do ImageKit.
class Instagram::PublishPostService
  GRAPH_BASE = 'https://graph.instagram.com/v22.0'.freeze
  STATUS_MAX_TRIES = 8       # imagem processa rapido
  STATUS_MAX_TRIES_VIDEO = 30 # video (reels/story) demora bem mais pra ficar FINISHED
  STATUS_INTERVAL = 2 # segundos entre checagens do container

  def initialize(post)
    @post = post
    @channel = post.inbox.channel
  end

  def perform
    return @post.mark_failed!('canal sem token') if access_token.blank?

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
  # economizar storage e limpa urls/file_ids (nao ha mais o que re-deletar no destroy).
  # So no sucesso; se falhar, mantem as midias pro retry.
  def cleanup_imagekit
    file_ids = @post.imagekit_file_ids
    Imagekit::DeleteFilesJob.perform_later(file_ids) if file_ids.present?
    # rubocop:disable Rails/SkipsModelValidations
    @post.update_columns(image_urls: [], image_file_ids: [], video_url: nil, video_file_id: nil)
    # rubocop:enable Rails/SkipsModelValidations
  end

  # Unifica publicar + automatizar: se o post trouxe uma automacao pendente, cria a
  # InstagramCommentAutomation JA com o media_id publicado (sem o usuario colar id).
  # Story nao suporta automacao de comentario.
  def create_pending_automation(media_id)
    cfg = @post.pending_automation
    return if cfg.blank? || !@post.supports_automation?

    @post.account.instagram_comment_automations.create!(pending_automation_attrs(cfg, media_id))
  rescue StandardError => e
    Rails.logger.error "[IG-PUBLISH] criar automacao pendente falhou (post #{@post.id}): #{e.message}"
  end

  def pending_automation_attrs(cfg, media_id)
    {
      inbox: @post.inbox, media_id: media_id, enabled: true,
      name: cfg['name'].presence || "Automação #{media_id}",
      keywords: cfg['keywords'], match_type: cfg['match_type'].presence || 'contains',
      dm_message: cfg['dm_message'], dm_link: cfg['dm_link'], dm_button_label: cfg['dm_button_label'],
      dm_buttons: Array(cfg['dm_buttons']), dm_image_url: cfg['dm_image_url'],
      dm_image_file_id: cfg['dm_image_file_id'], dm_card_title: cfg['dm_card_title'],
      public_reply: cfg['public_reply'], once_per_user: cfg.fetch('once_per_user', true)
    }
  end

  def create_and_publish
    creation_id = build_container
    return nil if creation_id.blank?
    return nil unless wait_until_ready(creation_id)

    publish(creation_id)
  end

  def build_container
    if @post.reels?
      build_reels
    elsif @post.story?
      build_story
    elsif @post.carousel?
      build_carousel
    else
      build_single
    end
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

  def build_reels
    create_container(media_type: 'REELS', video_url: @post.video_url, caption: @post.caption,
                     share_to_feed: @post.share_to_feed)
  end

  # Story: imagem OU video; nao leva legenda.
  def build_story
    params = { media_type: 'STORIES' }
    if @post.video_url.present?
      params[:video_url] = @post.video_url
    else
      params[:image_url] = @post.image_urls.first
    end
    create_container(params)
  end

  # POST /{ig_id}/media -> devolve o id do container (creation_id)
  def create_container(params)
    response = post("#{GRAPH_BASE}/#{ig_id}/media", params)
    return capture_error(response) unless response.success?

    response.parsed_response['id']
  end

  def wait_until_ready(creation_id)
    max_tries = @post.video? ? STATUS_MAX_TRIES_VIDEO : STATUS_MAX_TRIES
    max_tries.times do
      status = container_status(creation_id)
      return true if status == 'FINISHED'
      break if %w[ERROR EXPIRED].include?(status)

      sleep STATUS_INTERVAL
    end
    @error ||= 'processamento da mídia não concluído a tempo'
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
