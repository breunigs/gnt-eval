module CoursesHelper
  include FunkyTeXBits

  def render_preview
    texpreview(@course.summary)
  end

  def courseShowLink
    link_to("Show '#{@course.title}'", course_path(@course))
  end

  def courseEditLink
    link_to("Edit '#{@course.title}'", edit_course_path(@course))
  end

  def courseDestroyLink
    link_to_unless(@course.critical?, 'Destroy course', @course, \
      :confirm => "Really destroy course '#{@course.title}'?", \
      :method => :delete) do
      "⚠ Course is critical"
    end
  end

  def courseLinksForShowPage
    d = []
    d << courseEditLink
    d << courseDestroyLink unless @course.semester.critical?
    d.join(" | ")
  end

  def comment_image_link
    Seee::Config.file_paths[:comment_images_public_link]
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
        sortby << "title"
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
      order.map do |o|
        dat = eval("a.#{o}")
        data = dat.downcase if dat.is_a?(String)
        dat
      end
    end
    courses.reverse! if rev
    courses
  end
end
