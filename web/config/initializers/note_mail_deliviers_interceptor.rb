class NoteMailDeliveriesInterceptor
  def self.delivering_email(message)
    # Don't record debug mails
    unless message["X-GNT-Eval-Debug"]
      c = Course.find(message["X-GNT-Eval-Id"].to_s.to_i)
      x = "#{c.mails_sent || ""} #{message["X-GNT-Eval-Mail"]}".strip
      c.update_column("mails_sent", x)
    end
  end
end



ActionMailer::Base.register_interceptor(NoteMailDeliveriesInterceptor)
