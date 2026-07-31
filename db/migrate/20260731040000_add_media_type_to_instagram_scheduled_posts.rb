# Suporte a formatos: post (imagem/carrossel), reels (video) e story (imagem ou video).
# post_type define o formato; video_url/video_file_id guardam o video (reels/story).
class AddMediaTypeToInstagramScheduledPosts < ActiveRecord::Migration[7.1]
  def change
    change_table :instagram_scheduled_posts, bulk: true do |t|
      t.string :post_type, null: false, default: 'post'
      t.string :video_url
      t.string :video_file_id
      t.boolean :share_to_feed, null: false, default: true
    end
  end
end
