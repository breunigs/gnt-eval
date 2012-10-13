# encoding: utf-8

class CPicsController < ApplicationController
  def download
    @cpic = CPic.find(params[:id])
    raise ActionController::RoutingError.new("Original Sheet Could not be found. Looked in #{@cpic.source}") unless @cpic && File.exists?(@cpic.source)
    send_file(@cpic.source)
  end
end
