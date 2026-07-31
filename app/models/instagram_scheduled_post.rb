# == Schema Information
#
# Table name: instagram_scheduled_posts
#
#  id                 :bigint           not null, primary key
#  caption            :text
#  image_urls         :jsonb            not null
#  last_error         :text
#  permalink          :string
#  scheduled_at       :datetime
#  status             :string           default("scheduled"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  inbox_id           :bigint           not null
#  published_media_id :string
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
# Publicacao do Instagram (imagem unica ou carrossel) com agendamento opcional.
class InstagramScheduledPost < ApplicationRecord
  belongs_to :account
  belongs_to :inbox

  STATUSES = %w[scheduled publishing published failed].freeze
  MAX_IMAGES = 10 # limite de itens no carrossel do Instagram

  before_validation :compact_image_urls

  validates :status, inclusion: { in: STATUSES }
  validate :at_least_one_image
  validate :within_image_limit
  validate :inbox_belongs_to_account

  scope :due, -> { where(status: 'scheduled').where('scheduled_at IS NULL OR scheduled_at <= ?', Time.current) }

  def carousel?
    image_urls.size > 1
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
  end

  def at_least_one_image
    errors.add(:image_urls, 'inclua ao menos uma imagem') if image_urls.blank?
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
