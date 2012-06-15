# encoding: utf-8

class ApplicationController < ActionController::Base
  protect_from_forgery

  # returns the human name of the model associated with the current
  # controller. I18n is applied.
  def human_name
    controller_name.classify.constantize.model_name.human
  end
end
