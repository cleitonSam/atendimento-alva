# Cargos personalizados — implementação própria (MIT). Tabela `custom_roles` (OSS),
# `permissions` é um array de strings. As policies de enforcement (Enterprise::*Policy)
# checam `account_user.custom_role&.permissions`. Substitui o CustomRole do enterprise.
# == Schema Information
#
# Table name: custom_roles
#
#  id          :bigint           not null, primary key
#  description :string
#  name        :string
#  permissions :text             default([]), is an Array
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_custom_roles_on_account_id  (account_id)
#
class CustomRole < ApplicationRecord
  belongs_to :account
  has_many :account_users, dependent: :nullify

  validates :name, presence: true
end
