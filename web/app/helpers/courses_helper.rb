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
    params[:sort] = "faculty" if params[:sort].nil? || params[:sort].empty?
    sortby = []
    case params[:sort].gsub(/_rev$/, "")
      when "title" then
        sortby << "title.downcase"
      when "students" then
        sortby << "students"
        sortby << "title"
      when "evaluated_by" then
        sortby << "evaluator"
        sortby << "eval_date"
      when "profs" then
        sortby << "nl_separated_prof_fullname_list"
      when "description" then
        sortby << "eval_date"
        sortby << "description"
      when "faculty" then
        sortby << "faculty.shortname"
        sortby << "title"
    end
    sort(courses, sortby, params[:sort].match(/_rev$/))
  end

  def sort(courses, order, rev)
    return courses if order.empty?
    courses = courses.sort_by do |a|
      order.collect { |o| eval("a.#{o}") }
    end
    courses.reverse! if rev
    courses
  end
end
