# DM premium: card com imagem (generic template) + até 3 botões (web_url).
# dm_buttons = [{ "title" => "...", "url" => "..." }, ...] (máx 3). Os campos legados
# dm_link/dm_button_label continuam pro fallback das automações antigas.
class AddDmCardToInstagramCommentAutomations < ActiveRecord::Migration[7.1]
  def change
    change_table :instagram_comment_automations, bulk: true do |t|
      t.string :dm_image_url
      t.string :dm_image_file_id
      t.string :dm_card_title
      t.jsonb :dm_buttons, null: false, default: []
    end
  end
end
