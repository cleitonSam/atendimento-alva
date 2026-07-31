# Config de automacao (comente palavra-chave -> DM) que sera criada AUTOMATICAMENTE
# com o media_id do post assim que ele publicar (unifica publicar + automatizar; o
# usuario nao precisa descobrir/colar o media_id).
class AddPendingAutomationToInstagramScheduledPosts < ActiveRecord::Migration[7.1]
  def change
    add_column :instagram_scheduled_posts, :pending_automation, :jsonb
  end
end
