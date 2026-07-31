# Publica UMA InstagramScheduledPost. Idempotente: so age se ainda 'scheduled'
# (marca 'publishing' com lock, pra o enfileiramento imediato e a varredura cron
# nao publicarem duas vezes).
class Instagram::PublishInstagramPostJob < ApplicationJob
  queue_as :default

  def perform(post_id)
    post = InstagramScheduledPost.find_by(id: post_id)
    return unless post

    claimed = post.with_lock do
      next false unless post.status == 'scheduled'

      post.update!(status: 'publishing')
      true
    end
    return unless claimed

    Instagram::PublishPostService.new(post).perform
  end
end
