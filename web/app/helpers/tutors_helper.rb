module TutorsHelper
	def tutorEditLink
		link_to "Edit '#{@tutor.abbr_name}'", edit_tutor_path(@tutor)
	end

	def tutorReturnLink
		link_to "Return to '#{@tutor.course.title}'", @tutor.course
	end

	def comment_image_link
    Seee::Config.file_paths[:comment_images_public_link]
  end
end
