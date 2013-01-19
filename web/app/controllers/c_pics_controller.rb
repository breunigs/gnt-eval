# encoding: utf-8

class CPicsController < ApplicationController
  def download
    @cpic = CPic.find(params[:id])
    msg = "Original sheet not found. Try `locate #{File.basename @cpic.source}` (stored path:  #{@cpic.source})"
    raise ActionController::RoutingError.new(msg) unless @cpic && File.exists?(@cpic.source)
    send_file(@cpic.source)
  end
end
