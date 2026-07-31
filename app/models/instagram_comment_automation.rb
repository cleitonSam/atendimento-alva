# == Schema Information
#
# Table name: instagram_comment_automations
#
#  id                    :bigint           not null, primary key
#  dm_button_label       :string
#  dm_link               :string
#  dm_message            :text             not null
#  enabled               :boolean          default(TRUE), not null
#  ends_at               :datetime
#  handled_commenter_ids :jsonb            not null
#  keywords              :string
#  match_type            :string           default("contains"), not null
#  name                  :string           not null
#  once_per_user         :boolean          default(TRUE), not null
#  public_reply          :text
#  sent_count            :integer          default(0), not null
#  starts_at             :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  inbox_id              :bigint           not null
#  media_id              :string
#
# Indexes
#
#  index_instagram_comment_automations_on_account_id               (account_id)
#  index_instagram_comment_automations_on_account_id_and_media_id  (account_id,media_id)
#  index_instagram_comment_automations_on_inbox_id                 (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#
# Automacao comentario->DM do Instagram: numa publicacao (ou em qualquer uma), quem
# comentar a(s) palavra(s)-chave recebe uma DM automatica (template fixo + link/botao) e,
# opcionalmente, uma resposta publica no comentario. Janela de agendamento por starts/ends.
class InstagramCommentAutomation < ApplicationRecord
  belongs_to :account
  belongs_to :inbox

  MATCH_TYPES = %w[contains exact any].freeze

  validates :name, presence: true
  validates :dm_message, presence: true
  validates :match_type, inclusion: { in: MATCH_TYPES }
  validate :keywords_present_unless_any
  validate :inbox_belongs_to_account

  scope :enabled, -> { where(enabled: true) }

  def keyword_list
    keywords.to_s.split(',').map { |keyword| normalize(keyword) }.reject(&:blank?)
  end

  def within_window?(now = Time.current)
    (starts_at.nil? || starts_at <= now) && (ends_at.nil? || ends_at >= now)
  end

  # Casa com o texto do comentario conforme o match_type.
  def matches?(text)
    return true if match_type == 'any'

    normalized = normalize(text)
    return false if normalized.blank?

    if match_type == 'exact'
      keyword_list.include?(normalized)
    else
      keyword_list.any? { |keyword| normalized.include?(keyword) }
    end
  end

  # media_id vazio = vale pra qualquer post do canal.
  def applies_to_media?(media)
    media_id.blank? || media_id == media.to_s
  end

  def already_handled?(commenter_id)
    once_per_user? && handled_commenter_ids.include?(commenter_id.to_s)
  end

  # Marca o usuario como atendido (cap pra nao inflar o jsonb) e conta o envio.
  def record_dispatch!(commenter_id)
    self.handled_commenter_ids = (handled_commenter_ids + [commenter_id.to_s]).uniq.last(5000)
    self.sent_count += 1
    save!
  end

  private

  def normalize(text)
    text.to_s.downcase.strip.gsub(/\s+/, ' ')
  end

  def keywords_present_unless_any
    return if match_type == 'any' || keyword_list.present?

    errors.add(:keywords, 'informe pelo menos uma palavra-chave (ou use o tipo "qualquer")')
  end

  # Isolamento: o inbox tem que ser da MESMA conta (senao um admin poderia apontar
  # a automacao pro canal de outra conta).
  def inbox_belongs_to_account
    return if inbox_id.blank? || account_id.blank?

    errors.add(:inbox, 'nao pertence a esta conta') unless inbox&.account_id == account_id
  end
end
