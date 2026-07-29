# == Schema Information
#
# Table name: inbox_capacity_limits
#
#  id                       :bigint           not null, primary key
#  conversation_limit       :integer          not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  agent_capacity_policy_id :bigint           not null
#  inbox_id                 :bigint           not null
#

# Limite de conversas abertas por inbox dentro de uma política de capacidade.
# Reconstruído em MIT.
class InboxCapacityLimit < ApplicationRecord
  belongs_to :agent_capacity_policy
  belongs_to :inbox

  validates :conversation_limit, presence: true, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :inbox_id, uniqueness: { scope: :agent_capacity_policy_id }
end
