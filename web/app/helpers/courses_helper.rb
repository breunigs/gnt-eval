# encoding: utf-8

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
    ActiveSupport::JSON.encode(map_semesters_and_forms).html_safe
  end

  def courseShowLink
    link_to("Show '#{@course.title}'", course_path(@course), :class => "button")
  end

  def courseEditLink
    link_to("Edit '#{@course.title}'", edit_course_path(@course), :class => "button")
  end

  def courseDestroyLink
    link_to_unless(@course.critical?, 'Destroy course', @course, \
      :confirm => "Really destroy course '#{@course.title}'?", \
      :method => :delete,
      :class => "button") do
      "⚠ Course is critical"
    end
  end

  def courseLinksForShowPage
    d = []
    d << courseEditLink
    d << courseDestroyLink unless @course.semester.critical?
    d << link_to("Correlate", correlate_course_path(@course), :class => "button")
    d << link_to("List courses", semester_courses_path(@course.semester), :class => "button")
    %(<div class="button-group">#{d*""}</div>).html_safe
  end

  def comment_image_link
    Seee::Config.file_paths[:comment_images_public_link]
  end
end
