# Engajamento na publicacao:
#   first_comment -> 1o comentario automatico (hashtags/CTA sem sujar a legenda)
#   auto_story    -> ao publicar no feed, republica a capa como Story (puxa quem ve story)
class AddEngagementToInstagramScheduledPosts < ActiveRecord::Migration[7.1]
  def change
    change_table :instagram_scheduled_posts, bulk: true do |t|
      t.text :first_comment
      t.boolean :auto_story, null: false, default: false
    end
  end
end
