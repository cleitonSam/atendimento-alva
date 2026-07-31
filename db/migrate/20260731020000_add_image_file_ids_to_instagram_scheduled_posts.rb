# Guarda os fileId do ImageKit (paralelo a image_urls) pra poder DELETAR as imagens
# no ImageKit quando a publicacao for excluida (senao acumula lixo la).
class AddImageFileIdsToInstagramScheduledPosts < ActiveRecord::Migration[7.1]
  def change
    add_column :instagram_scheduled_posts, :image_file_ids, :jsonb, null: false, default: []
  end
end
