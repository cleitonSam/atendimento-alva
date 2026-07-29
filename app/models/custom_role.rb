# Cargos personalizados — implementação própria (MIT). Tabela `custom_roles` (OSS),
# `permissions` é um array de strings. As policies de enforcement (Enterprise::*Policy)
# checam `account_user.custom_role&.permissions`. Substitui o CustomRole do enterprise.
class CustomRole < ApplicationRecord
  belongs_to :account
  has_many :account_users, dependent: :nullify

  validates :name, presence: true
end
