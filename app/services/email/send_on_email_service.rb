class Email::SendOnEmailService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Email
  end

  def perform_reply
    return unless message.email_notifiable_message?

    reply_mail = ConversationReplyMailer.with(account: message.account).email_reply(message).deliver_now
    source_id = reply_mail.try(:message_id)

    # email_reply devolve nil quando o envio nao esta configurado (sem SMTP no canal,
    # sem SMTP global e sem IMAP+OAuth). Sem essa guarda, o reply_mail.message_id
    # estourava 'undefined method message_id for nil' e caia no rescue com esse texto cru.
    return mark_smtp_not_configured if source_id.blank?

    Rails.logger.info("Email message #{message.id} sent with source_id: #{source_id}")
    message.update(source_id: source_id)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: message.account).capture_exception
    Messages::StatusUpdateService.new(message, 'failed', e.message).perform
  end

  def mark_smtp_not_configured
    Rails.logger.warn("Email message #{message.id} nao enviado: SMTP de envio nao configurado para a inbox de e-mail")
    Messages::StatusUpdateService.new(
      message, 'failed',
      'Nao foi possivel enviar: configure o SMTP desta caixa de e-mail (Configuracao da inbox -> SMTP).'
    ).perform
  end
end
