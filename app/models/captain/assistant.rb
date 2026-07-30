# Captain::Assistant — reconstrução MIT (o backend do Captain vivia em enterprise/,
# que foi removido). Tabela captain_assistants já existe/migrada. Um "assistente" é o
# dono das FAQs sugeridas e das respostas aprovadas, escopado por conta.
# == Schema Information
#
# Table name: captain_assistants
#
#  id                  :bigint           not null, primary key
#  config              :jsonb            not null
#  description         :text
#  guardrails          :jsonb
#  name                :string           not null
#  response_guidelines :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_captain_assistants_on_account_id  (account_id)
#
class Captain::Assistant < ApplicationRecord
  self.table_name = 'captain_assistants'

  belongs_to :account
  has_many :faq_suggestions, class_name: 'Captain::FaqSuggestion', foreign_key: :assistant_id,
                             dependent: :destroy, inverse_of: :assistant
  has_many :responses, class_name: 'Captain::AssistantResponse', foreign_key: :assistant_id,
                       dependent: :destroy, inverse_of: :assistant

  validates :name, presence: true
end
