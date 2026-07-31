# Publicacao (carrossel) do Instagram, com agendamento. As imagens vao pro ImageKit
# (URL publica) e a publicacao usa a Content Publishing API da Graph.
class CreateInstagramScheduledPosts < ActiveRecord::Migration[7.1]
  def change
    create_table :instagram_scheduled_posts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.text :caption
      t.jsonb :image_urls, null: false, default: []   # URLs publicas (ImageKit)
      t.datetime :scheduled_at                          # nil/passado = publica agora
      t.string :status, null: false, default: 'scheduled' # scheduled|publishing|published|failed
      t.string :published_media_id
      t.string :permalink
      t.text :last_error
      t.timestamps
    end

    add_index :instagram_scheduled_posts, [:status, :scheduled_at]
  end
end
