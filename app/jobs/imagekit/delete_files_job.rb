# Deleta as imagens no ImageKit em background (nao trava a exclusao da publicacao,
# e uma falha no ImageKit nao impede o delete do registro).
class Imagekit::DeleteFilesJob < ApplicationJob
  queue_as :low

  def perform(file_ids)
    Imagekit::DeleteService.new(file_ids: file_ids).perform
  end
end
