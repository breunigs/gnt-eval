# encoding: utf-8

class ApplicationController < ActionController::Base
  protect_from_forgery


  # be able to run the app from a suburi
  # via http://www.philipp.haussleiter.de/2012/02/running-a-rails-3-application-in-a-sub-uri-enviroment/
  before_filter :action_set_url_options
  def action_set_url_options
    if ENV['RAILS_RELATIVE_URL_ROOT']
      @host = request.host+":"+request.port.to_s+"/"+ENV['RAILS_RELATIVE_URL_ROOT']
    else
      @host = request.host+":"+request.port.to_s
    end
    Rails.application.routes.default_url_options = { :host => @host}
  end

  # returns the human name of the model associated with the current
  # controller. I18n is applied.
  def human_name
    controller_name.classify.constantize.model_name.human
  end
end
