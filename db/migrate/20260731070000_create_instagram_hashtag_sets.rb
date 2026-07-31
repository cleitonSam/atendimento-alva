# Conjuntos de hashtags reutilizaveis (ex.: "Treino", "Promo") por conta.
class CreateInstagramHashtagSets < ActiveRecord::Migration[7.1]
  def change
    create_table :instagram_hashtag_sets do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :hashtags, null: false, default: ''
      t.timestamps
    end
  end
end
