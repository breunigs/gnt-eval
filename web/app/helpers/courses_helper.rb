module CoursesHelper
  include FunkyTeXBits

  # finds all available languages in all forms
  def all_langs
    l = []
    Semester.all.each do |s|
      s.forms.each { |f| l << f.languages }
    end
    l.flatten.uniq
  end

  # maps given forms to a hash of hashs like:
  # { form_id => { :name => "some form", :langs => [:de, :en] } }
  def map_forms_and_langs(forms)
    h = {}
    forms.each do |f|
      h[f.id] = { :name => f.name, :langs => f.languages }
    end
    h
  end

  # maps all semesters to a hashs of hashs like:
  # { semester_id => { :title => "WS 10/11", :forms => (see above) } }
  def map_semesters_and_forms
    sfl = {}
    Semester.all.each do |s|
      sfl[s.id] = { :title => s.title, :forms => map_forms_and_langs(s.forms) }
    end
    sfl
  end

  # returns a JSON version of map_semesters_and_forms
  def json_map_sfl
    ActiveSupport::JSON.encode(map_semesters_and_forms)
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
        sortby << "title.downcase"
      when "students" then
        sortby << "students"
        sortby << "title.downcase"
      when "evaluated_by" then
        sortby << "evaluator.downcase"
        sortby << "eval_date"
      when "profs" then
        sortby << "nl_separated_prof_fullname_list.downcase"
      when "description" then
        sortby << "eval_date"
        sortby << "description.downcase"
      when "faculty" then
        sortby << "faculty.shortname.downcase"
        sortby << "title.downcase"
    end
    sort(courses, sortby, params[:sort].match(/_rev$/))
  end

  def sort(courses, order, rev)
    return courses if order.empty?
    courses = courses.sort_by do |a|
      order.map { |o| eval("a.#{o}") }
    end
    courses.reverse! if rev
    courses
  end
end
