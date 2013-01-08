# encoding: utf-8

class HitmesController < ApplicationController
  def overview
    render :action => "overview"
  end

  def assign_work
    t = Term.currently_active.map(&:id)

    all = CPic.joins(:course).where("courses.term_id" => t, "step" => [nil, 0])
    all += Pic.joins(:course).where("courses.term_id" => t, "step" => [nil, 0])

    # don’t hand out ones that are currently being edited
    all.reject! { |a| Session.exists?(:cont => a.class.to_s.downcase, :viewed_id => a.id) }

    if all.empty?
      redirect_to :action => "overview"
    else
      @workon = all.sample

      # make collision detection happy
      params[:controller] = @workon.class.to_s.downcase
      params[:id] = @workon.id

      if @workon.step == 0 || @workon.step.nil?
        render :action => "type"
      end
    end
  end

  def save_comment
    # FIXME
  end

  def cookie_test
    render :json => cookies[:testcookie] == "test value"
  end
end
