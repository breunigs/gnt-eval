# encoding: utf-8

class PicsController < ApplicationController
  def download
    @pic = Pic.find(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless @pic && File.exists?(@pic.source)
    send_file(@pic.source)
  end
end
