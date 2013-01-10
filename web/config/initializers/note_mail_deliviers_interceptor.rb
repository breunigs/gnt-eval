class NoteMailDeliveriesInterceptor
  def self.delivering_email(message)
    message.perform_deliveries = false

    c = Course.find(message["X-GNT-Eval-Id"].to_s.to_i)
    x = "#{c.mails_sent || ""} #{message["X-GNT-Eval-Mail"]}".strip
    c.update_column("mails_sent", x)
  end
end



ActionMailer::Base.register_interceptor(NoteMailDeliveriesInterceptor)
