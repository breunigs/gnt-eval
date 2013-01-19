# encoding: utf-8

class PicsController < ApplicationController
  def download
    @pic = Pic.find(params[:id])
    msg = "Original sheet not found. Try `locate #{File.basename @pic.source}` (stored path:  #{@pic.source})" 
    raise ActionController::RoutingError.new(msg) unless @pic && File.exists?(@pic.source)
    send_file(@pic.source)
  end
end
