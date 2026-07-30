# Empresas (agrupa contatos) — implementação própria (MIT). Tabela `companies` (OSS),
# contatos ligam por `contacts.company_id`. Substitui o Company do enterprise.
# == Schema Information
#
# Table name: companies
#
#  id                    :bigint           not null, primary key
#  additional_attributes :jsonb
#  contacts_count        :integer
#  custom_attributes     :jsonb
#  description           :text
#  domain                :string
#  last_activity_at      :datetime
#  name                  :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#
# Indexes
#
#  index_companies_on_account_and_domain   (account_id,domain) UNIQUE WHERE (domain IS NOT NULL)
#  index_companies_on_account_id           (account_id)
#  index_companies_on_name_and_account_id  (name,account_id)
#
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
