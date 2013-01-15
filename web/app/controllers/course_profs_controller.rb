# encoding: utf-8

class CourseProfsController < ApplicationController
  def print
    @cp = CourseProf.find(params[:id])
    if @cp.print_in_progress?
      flash[:warning] = "Printing already in progress. Can’t you be patient?"
    elsif @cp.returned_sheets?
      flash[:error] = "Can’t print new forms if there are already existing ones. If you need more sheets, read the how to."
    else


      if @cp.print_execute == 0
        flash[:notice] = "Printing job has been submitted. Most likely, the printer will output your sheets soon."
      else
        flash[:error] = "Printing did not work. There is nothing you can do about it. Call for help."
      end
    end

    # redirect back to course
    redirect_to(@cp.course)
  end
end
