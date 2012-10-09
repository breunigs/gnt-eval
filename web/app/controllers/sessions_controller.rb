# encoding: utf-8

class SessionsController < ApplicationController
  def ping
    if params[:ident]
      x = Session.where(:cont => params[:cont], :viewed_id => params[:viewed_id],
        :ident => params[:ident]).first_or_create!
      x.agent = request.env['HTTP_USER_AGENT']
      x.ip = request.env['REMOTE_ADDR']
      x.username = (cookies["username"] || "").gsub(/[^a-z0-9-_\s]/i, "")[0..20]
      x.save
    end

    @viewers = Session.where(:cont => params[:cont], :viewed_id => params[:viewed_id])
    users = @viewers.map do |v|
      v.username.blank? ? v.ident : v.username
    end
    render :json => { :viewers => @viewers.count, :users => users }
  end

  def unping
    Session.destroy_all(:cont => params[:cont],
      :viewed_id => params[:viewed_id], :ident => params[:ident])
    render :nothing => true

    # cleanup in 5% of the cases, but don't hold off
    Thread.new do; begin
      Session.unscoped.destroy_all(["updated_at < ?", 1.minutes.ago]) if rand <= 0.05
    rescue; end; end
  end
end
