# == Schema Information
#
# Table name: instagram_comment_automations
#
#  id                    :bigint           not null, primary key
#  dm_button_label       :string
#  dm_buttons            :jsonb            not null
#  dm_card_title         :string
#  dm_image_url          :string
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
#  dm_image_file_id      :string
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
  MAX_BUTTONS = 3           # limite do Instagram (button/generic template)
  BUTTON_TITLE_LIMIT = 20   # limite do título do botão no Instagram
  CARD_TEXT_LIMIT = 80      # título/subtítulo do generic template

  before_validation :normalize_dm_buttons

  validates :name, presence: true
  validates :dm_message, presence: true
  validates :match_type, inclusion: { in: MATCH_TYPES }
  validate :keywords_present_unless_any
  validate :inbox_belongs_to_account
  validate :dm_buttons_shape
  validate :card_title_present_with_image

  scope :enabled, -> { where(enabled: true) }

  # Card = tem imagem de capa (vira generic template na DM).
  def dm_card?
    dm_image_url.present?
  end

  # Botões normalizados pro payload do Instagram: [{type, url, title}], no máx 3.
  # Fallback: automações antigas (sem dm_buttons) usam o par legado dm_link/dm_button_label.
  def dm_buttons_for_payload
    source = dm_buttons.presence || legacy_button
    Array(source).filter_map do |btn|
      url = btn['url'].to_s.strip
      next if url.blank?

      { type: 'web_url', url: url, title: (btn['title'].presence || 'Abrir').to_s[0, BUTTON_TITLE_LIMIT] }
    end.first(MAX_BUTTONS)
  end

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

  # Reserva o usuario ATOMICAMENTE (lock + re-check dentro do lock) pra dois webhooks
  # simultaneos do mesmo comentador nao gerarem DM dupla. Retorna false se ja atendido.
  def claim_dispatch!(commenter_id)
    with_lock do
      next false if already_handled?(commenter_id)

      self.handled_commenter_ids = (handled_commenter_ids + [commenter_id.to_s]).uniq.last(5000)
      save!
      true
    end
  end

  # Desfaz a reserva quando o envio falhou por completo (pra um retry poder tentar).
  def unclaim_dispatch!(commenter_id)
    with_lock do
      self.handled_commenter_ids = handled_commenter_ids - [commenter_id.to_s]
      save!
    end
  end

  # Incrementa a contagem via SQL (atomico, sem read-modify-write).
  def count_sent!
    self.class.increment_counter(:sent_count, id) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def legacy_button
    dm_link.present? ? [{ 'url' => dm_link, 'title' => dm_button_label }] : []
  end

  # Aceita array de {title,url}; joga fora entradas sem url; corta em MAX_BUTTONS.
  def normalize_dm_buttons
    self.dm_buttons = Array(dm_buttons).filter_map do |btn|
      btn = btn.to_h.stringify_keys if btn.respond_to?(:to_h)
      url = btn['url'].to_s.strip
      next if url.blank?

      { 'url' => url, 'title' => btn['title'].to_s.strip }
    end.first(MAX_BUTTONS)
  end

  def dm_buttons_shape
    Array(dm_buttons).each do |btn|
      errors.add(:dm_buttons, 'link inválido (use http/https)') unless btn['url'].to_s.match?(%r{\Ahttps?://}i)
    end
  end

  # Generic template exige um título; sem imagem não há card (usa button/text template).
  def card_title_present_with_image
    errors.add(:dm_card_title, 'informe um título para o card') if dm_card? && dm_card_title.blank?
  end

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
