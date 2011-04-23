module TutorsHelper
  include FunkyTeXBits

  def render_preview
    texpreview(@tutor.comment)
  end

  def tutor_edit_link
    link_to "Edit '#{@tutor.abbr_name}'", edit_tutor_path(@tutor)
  end

  def tutor_return_link
    link_to "Return to '#{@tutor.course.title}'", @tutor.course
  end

  def comment_image_link
    Seee::Config.file_paths[:comment_images_public_link]
  end
end
