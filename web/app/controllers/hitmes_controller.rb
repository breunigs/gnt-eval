# encoding: utf-8

class HitmesController < ApplicationController
  def overview
    render :action => "overview"
  end

  def assign_work
    # typing and proofreading basically work the same
    @workon = Hitme.get_workable_comment_by_step(0)
    @workon ||= Hitme.get_workable_comment_by_step(1)
    @workon = Hitme.get_combinable # FIXME

    if @workon.nil?
      flash[:notice] = "Currently no available tasks. Try again later."
      redirect_to :action => "overview"
    else
      # make collision detection happy
      params[:controller] = @workon.class.to_s.pluralize.downcase
      params[:id] = @workon.id

      @ident = precreate_session(@workon)

      case @workon.class.to_s
        when "Pic"  then render :action => "type_proofread"
        when "CPic" then render :action => "type_proofread"
        when "Tutor"  then render :action => "combine"
        when "Course" then render :action => "combine"
        else raise "not implemented"
      end
    end
  end

  # handles updating text and step for comment typing and proofreading.
  # automatically redirects the user according to the action chosen.
  def save_comment
    x = case params[:type]
      when "CPic" then CPic.find(params[:id])
      when  "Pic" then Pic.find(params[:id])
      else nil
    end

    if params[:cancel] || x.nil?
      flash[:error] = "The comment image in question could not be found." if x.nil?
      redirect_to :action => "overview"

    elsif params[:save_and_skip]
      x.text = params[:text]
       # initialize step to 0, otherwise the validations might fail
      x.step ||= 0
      flash[:error] = "Your changes could not be saved. Please investigate." if not x.save
      redirect_to :action => "assign_work"

    elsif params[:save_and_quit] || params[:save_and_give]
      x.text = params[:text]

      next_step = { nil => 1, 0 => 1, 1 => 2 }
      if next_step.keys.include?(x.step)
        x.step = next_step[x.step]
      else
        flash[:warning] = "Could not advance step, there might have been a collision. You shouldn’t worry too much about it though."
      end

      if x.save
        flash[:notice] = "Changes have been saved."
      else
        flash[:error] = "Your changes could not be saved. Please investigate before continuing."
      end

      redirect_to :action => params[:save_and_quit] ? "overview" : "assign_work"

    else
      flash[:error] = "Invalid action given. Your comment was not saved."
      redirect_to :action => "overview"
    end
  end


  def preview_text
    text = params[:text]
    text = params[:listify].to_s == "true" ? view_context.text_to_list(text) : text
    render :partial => "shared/preview", :locals => {
      :text => text,
      :disable_cache => true}
  end


  def cookie_test
    render :json => cookies[:testcookie] == "test value"
  end

  private
  def precreate_session(workon)
    # golf via http://stackoverflow.com/a/88341/1684530
    ident = (0...9).map{65.+(rand(26)).chr}.join.downcase

    x = Session.new(:cont => workon.class.to_s.downcase, :viewed_id => workon.id)
    x.ident = ident
    x.agent = request.env['HTTP_USER_AGENT']
    x.ip = request.env['REMOTE_ADDR']
    x.username = (cookies["username"] || "").gsub(/[^a-z0-9_\s-]/i, "")[0..20]
    x.save
    ident
  end
end
