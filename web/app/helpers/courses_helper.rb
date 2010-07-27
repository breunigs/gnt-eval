module CoursesHelper
	def courseEditLink
		link_to("Edit '#{@course.title}'", edit_course_path(@course))
	end

	def courseReturnLink
		link_to('Return to courses list', courses_path)
	end

	def courseDestroyLink
		link_to('Delete course', @course, :confirm => "Really delete course '#{@course.title}'?", :method => :delete)
	end

	def courseShowLink
		link_to("Show '#{@course.title}'", @course)
	end

	def courseLinksForShowPage
		d = []
		# doesn't make too much sense when viewing a course?
		#d << link_to('New', new_course_path)
		d << courseEditLink
		# FIXME this link should be hidden automatically around eval week
		d << courseDestroyLink
		d << courseReturnLink
		d.join(" | ")
	end

	def sort_class(param)
		key = param.gsub(" ", "_").downcase
		return 'class="sortup"' if params[:sort] == key
		return 'class="sortdown"' if params[:sort] == key + "_rev"
		''
	end

	def sort_link(param)
		key = param.gsub(" ", "_").downcase
		key += "_rev" if params[:sort] == key
		link_to(param, :sort => key)
	end

	def sort_helper(courses)
		return courses if params[:sort].nil? || params[:sort].empty?
		courses = case params[:sort].gsub(/_rev$/, "")
			when "title" 		then courses.sort_by { |c| c.title }
			when "students"     then courses.sort_by { |c| c.students }
			when "evaluated_by" then courses.sort_by { |c| c.evaluator }
			when "profs"        then courses.sort_by { |c| c.profs.map { |p| p.fullname + " " } }
			when "description"  then courses.sort_by { |c| c.description }
			when "faculty"      then courses.sort do |a, b|
					x = a.faculty.shortname
					y = b.faculty.shortname
					x == y ? a.title <=> b.title : x <=> y
				end
			else   				     courses.sort_by { |c| c.title }
		end
		courses.reverse! if params[:sort].match(/_rev$/)
		courses
	end
end
