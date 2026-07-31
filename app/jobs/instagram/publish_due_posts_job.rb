# Varredura (cron, a cada minuto): enfileira a publicacao dos posts agendados que
# ja venceram (scheduled_at <= agora, ou sem data). A idempotencia fica no
# PublishInstagramPostJob (lock + status).
class Instagram::PublishDuePostsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    InstagramScheduledPost.due.find_each do |post|
      Instagram::PublishInstagramPostJob.perform_later(post.id)
    end
  end
end
