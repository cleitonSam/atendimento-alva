# Empresas (agrupa contatos) — implementação própria (MIT). Tabela `companies` (OSS),
# contatos ligam por `contacts.company_id`. Substitui o Company do enterprise.
class Company < ApplicationRecord
  include Avatarable

  belongs_to :account
  has_many :contacts, dependent: :nullify

  validates :name, presence: true
  validates :account_id, presence: true
  validates :domain,
            uniqueness: { scope: :account_id, case_sensitive: false },
            allow_blank: true

  before_validation :normalize_domain

  private

  def normalize_domain
    self.domain = domain.presence&.strip&.downcase
  end
end
