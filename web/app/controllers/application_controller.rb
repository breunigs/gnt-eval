# encoding: utf-8

class ApplicationController < ActionController::Base
  protect_from_forgery

  # Set UTF-8 header on everything.
  before_filter :set_utf8_header
  def set_utf8_header
    response.headers['Content-type'] = 'text/html; charset=utf-8'
  end

  # returns the human name of the model associated with the current
  # controller. I18n is applied.
  def human_name
    controller_name.classify.constantize.model_name.human
  end
end
