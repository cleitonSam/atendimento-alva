# == Schema Information
#
# Table name: instagram_scheduled_posts
#
#  id                 :bigint           not null, primary key
#  auto_story         :boolean          default(FALSE), not null
#  caption            :text
#  first_comment      :text
#  image_file_ids     :jsonb            not null
#  image_urls         :jsonb            not null
#  last_error         :text
#  pending_automation :jsonb
#  permalink          :string
#  post_type          :string           default("post"), not null
#  scheduled_at       :datetime
#  share_to_feed      :boolean          default(TRUE), not null
#  status             :string           default("scheduled"), not null
#  video_url          :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  inbox_id           :bigint           not null
#  published_media_id :string
#  video_file_id      :string
#
# Indexes
#
#  index_instagram_scheduled_posts_on_account_id               (account_id)
#  index_instagram_scheduled_posts_on_inbox_id                 (inbox_id)
#  index_instagram_scheduled_posts_on_status_and_scheduled_at  (status,scheduled_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#
# Publicacao do Instagram com agendamento opcional. Formatos:
#   - post  -> imagem unica ou carrossel (image_urls)
#   - reels -> video (video_url)
#   - story -> imagem OU video (dura 24h; sem legenda; nao recebe automacao de comentario)
class InstagramScheduledPost < ApplicationRecord
  belongs_to :account
  belongs_to :inbox

  STATUSES = %w[scheduled publishing published failed].freeze
  POST_TYPES = %w[post reels story].freeze
  MAX_IMAGES = 10 # limite de itens no carrossel do Instagram

  before_validation :compact_image_urls

  validates :status, inclusion: { in: STATUSES }
  validates :post_type, inclusion: { in: POST_TYPES }
  validate :media_present
  validate :within_image_limit
  validate :inbox_belongs_to_account

  scope :due, -> { where(status: 'scheduled').where('scheduled_at IS NULL OR scheduled_at <= ?', Time.current) }

  def reels?
    post_type == 'reels'
  end

  def story?
    post_type == 'story'
  end

  # story pode ser video; reels e sempre video
  def video?
    reels? || (story? && video_url.present?)
  end

  def carousel?
    post_type == 'post' && image_urls.size > 1
  end

  # Story nao aceita legenda no Instagram; automacao de comentario/1o comentario so faz
  # sentido em conteudo que aparece no feed/reels (story nao tem thread de comentarios).
  def supports_automation?
    !story?
  end

  # Auto-story: ao publicar no feed, a capa (image_urls.first) vira um Story pra puxar
  # quem ve story pro post. So pra post de feed com imagem (nao Story, nao Reels de video).
  def wants_auto_story?
    auto_story? && post_type == 'post' && image_urls.present?
  end

  # Todos os fileIds do ImageKit desta publicacao (pra limpar apos publicar / no destroy).
  def imagekit_file_ids
    (Array(image_file_ids) + [video_file_id]).filter_map(&:presence)
  end

  def mark_published!(media_id, permalink)
    update!(status: 'published', published_media_id: media_id, permalink: permalink, last_error: nil)
  end

  def mark_failed!(message)
    update!(status: 'failed', last_error: message.to_s[0, 500])
  end

  private

  # Remove URLs em branco (o Rack manda [] como [''] em form params) e normaliza.
  def compact_image_urls
    self.image_urls = Array(image_urls).map { |url| url.to_s.strip }.reject(&:blank?)
    self.image_file_ids = Array(image_file_ids).map { |fid| fid.to_s.strip }
  end

  # Cada formato exige a sua midia.
  def media_present
    case post_type
    when 'reels'
      errors.add(:video_url, 'inclua o video do reels') if video_url.blank?
    when 'story'
      errors.add(:base, 'inclua uma imagem ou um video') if image_urls.blank? && video_url.blank?
    else # post
      errors.add(:image_urls, 'inclua ao menos uma imagem') if image_urls.blank?
    end
  end

  def within_image_limit
    errors.add(:image_urls, "no maximo #{MAX_IMAGES} imagens") if image_urls.size > MAX_IMAGES
  end

  # Isolamento: o inbox tem que ser da MESMA conta.
  def inbox_belongs_to_account
    return if inbox_id.blank? || account_id.blank?

    errors.add(:inbox, 'nao pertence a esta conta') unless inbox&.account_id == account_id
  end
end
