# encoding: utf-8

require 'pp'

class CourseProfsController < ApplicationController
  def print
    @cp = CourseProf.find(params[:id])
    if @cp.print_in_progress?
      flash[:warning] = "Printing already in progress. Can’t you be patient?"
    elsif @cp.returned_sheets?
      flash[:error] = "Can’t print new forms if there are already existing ones. If you need more sheets, read the how to."
    else
      @cp.print_in_progress = true
      pdf_path = temp_dir("print_forms")

      # ensure the howtos exist
      create_howtos(temp_dir("howtos"), pdf_path)
      # create form
      make_pdf_for(@cp, pdf_path)
      # print!
      p = Seee::Config.application_paths[:print]
      p << " --non-interactive \""
      p << File.join(pdf_path, @cp.get_filename)
      p << ".pdf\""
      `#{p}`

      if $?.exitstatus == 0
	flash[:notice] = "Printing job has been submitted. Most likely, the printer will output your sheets soon."
      else
	flash[:error] = "Printing did not work. There is nothing you can do about it. Call for help."
      end

      # run once again, so all newly created files are accessible by
      # everyone
      temp_dir

      @cp.print_in_progress = false
    end

    # redirect back to course
    redirect_to(@cp.course)
  end
end

