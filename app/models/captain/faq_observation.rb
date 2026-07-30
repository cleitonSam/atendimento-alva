# Captain::FaqObservation — reconstrução MIT. Cada "observação" é uma conversa que deu
# origem a uma FAQ sugerida (a fonte). Uma FAQ agrega várias observações (source_count).
# Índice único [conversation_id, faq_suggestion_id] evita duplicar a mesma fonte.
# == Schema Information
#
# Table name: captain_faq_observations
#
#  id                 :bigint           not null, primary key
#  generated_answer   :text             not null
#  generated_question :string           not null
#  language           :string           default("en"), not null
#  status             :integer          default(0), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  conversation_id    :bigint           not null
#  faq_suggestion_id  :bigint
#
# Indexes
#
#  idx_captain_faq_observations_on_conversation_and_suggestion  (conversation_id,faq_suggestion_id) UNIQUE WHERE (faq_suggestion_id IS NOT NULL)
#  index_captain_faq_observations_on_account_id                 (account_id)
#  index_captain_faq_observations_on_conversation_id            (conversation_id)
#  index_captain_faq_observations_on_faq_suggestion_id          (faq_suggestion_id)
#
class Captain::FaqObservation < ApplicationRecord
  self.table_name = 'captain_faq_observations'

  belongs_to :account
  belongs_to :conversation
  belongs_to :faq_suggestion, class_name: 'Captain::FaqSuggestion', optional: true

  validates :generated_question, presence: true
  validates :generated_answer, presence: true
end
