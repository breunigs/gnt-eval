# encoding: utf-8

class SessionsController < ApplicationController
  def ping
    if params[:ident]
      Session.where(:cont => params[:cont], :viewed_id => params[:viewed_id],
        :ident => params[:ident]).first_or_create!.touch
    end

    @viewers = Session.where(:cont => params[:cont], :viewed_id => params[:viewed_id])
    render :json => @viewers.count
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
