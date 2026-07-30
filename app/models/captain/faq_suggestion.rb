# Captain::FaqSuggestion — reconstrução MIT. FAQ (pergunta+resposta) proposta pela IA
# a partir de conversas resolvidas, aguardando revisão. status open(0) casa com o
# filtro que o front sempre manda (status='open'). Aprovar -> vira AssistantResponse.
# == Schema Information
#
# Table name: captain_faq_suggestions
#
#  id           :bigint           not null, primary key
#  answer       :text             not null
#  embedding    :vector(1536)
#  language     :string           default("en"), not null
#  question     :string           not null
#  source_count :integer          default(0), not null
#  status       :integer          default("open"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  assistant_id :bigint           not null
#
# Indexes
#
#  idx_cap_faq_suggestions_on_account_assistant_status_language  (account_id,assistant_id,status,language)
#  index_captain_faq_suggestions_on_account_id                   (account_id)
#  index_captain_faq_suggestions_on_assistant_id                 (assistant_id)
#  vector_idx_captain_faq_suggestions_embedding                  (embedding) USING ivfflat
#
class Captain::FaqSuggestion < ApplicationRecord
  self.table_name = 'captain_faq_suggestions'

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'
  has_many :observations, class_name: 'Captain::FaqObservation', foreign_key: :faq_suggestion_id,
                          dependent: :nullify, inverse_of: :faq_suggestion

  enum status: { open: 0, approved: 1, dismissed: 2 }

  validates :question, presence: true
  validates :answer, presence: true
end
