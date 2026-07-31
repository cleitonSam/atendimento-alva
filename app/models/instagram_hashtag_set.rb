# == Schema Information
#
# Table name: instagram_hashtag_sets
#
#  id         :bigint           not null, primary key
#  hashtags   :text             default(""), not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_instagram_hashtag_sets_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
# Conjunto de hashtags reutilizavel (ex.: "Treino", "Promo") pra inserir na legenda ou
# no 1o comentario com 1 clique. `hashtags` guarda o texto cru (ex.: "#treino #foco ...").
class InstagramHashtagSet < ApplicationRecord
  belongs_to :account

  validates :name, presence: true

  # Quantidade de hashtags (Instagram permite ate 30 no total entre legenda + comentario).
  def tag_count
    hashtags.to_s.scan(/#[\p{Word}]+/).size
  end
end
