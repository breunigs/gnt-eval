module TutorsHelper
	def tutorEditLink
		link_to "Edit '#{@tutor.abbr_name}'", edit_tutor_path(@tutor)
	end

	def tutorReturnLink
		link_to "Return to '#{@tutor.course.title}'", @tutor.course
	end

	def tutorShowLink
		link_to "Show/Preview '#{@tutor.abbr_name}'", @tutor
	end
end
