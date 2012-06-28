# encoding: utf-8

module TutorsHelper
  include FunkyTeXBits

  def tutor_edit_link
    link_to "✎ Edit '#{@tutor.abbr_name}'", edit_course_tutor_path(@tutor.course, @tutor), :class => "button"
  end

  def tutor_return_link
    link_to "⤶ Return to '#{@tutor.course.title}'", @tutor.course, :class => "button"
  end

  def tutor_result_pdf_link
    render 'shared/hold_button', :url => course_tutor_result_pdf_path(@tutor.course, @tutor), :name => "⬇ result.pdf (slow)", :id => "resultpdf", :button => true
  end

  def comment_image_link
    Seee::Config.file_paths[:comment_images_public_link]
  end
end
