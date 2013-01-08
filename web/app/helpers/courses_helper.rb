# encoding: utf-8

module CoursesHelper
  include FunkyTeXBits

  # finds all available languages in all forms
  def all_langs
    l = []
    Term.all.each do |s|
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

  # maps all terms to a hashs of hashs like:
  # { term_id => { :title => "WS 10/11", :forms => (see above) } }
  def map_terms_and_forms
    tfl = {}
    Term.all.each do |s|
      tfl[s.id] = { :title => s.title, :forms => map_forms_and_langs(s.forms) }
    end
    tfl
  end

  # returns a JSON version of map_terms_and_forms
  def json_map_sfl
    ActiveSupport::JSON.encode(map_terms_and_forms).html_safe
  end

  def courseShowLink
    link_to("Show “#{@course.title}”", course_path(@course), :class => "button")
  end

  def courseEditLink
    link_to("✎ Edit “#{@course.title}”", edit_course_path(@course), :class => "button primary")
  end

  def courseDestroyLink
    link_to_unless(@course.critical?, 'Destroy course', @course, \
      :confirm => "Really destroy course '#{@course.title}'?", \
      :method => :delete,
      :class => "button") do
      "&nbsp;⚠ Course is critical".html_safe
    end
  end

  def courseLinksForShowPage
    d = []
    d << courseEditLink
    d << courseDestroyLink unless @course.term.critical?
    d << link_to("ϱ Correlate", correlate_course_path(@course), :class => "button")
    d << link_to("⤶ List courses", term_courses_path(@course.term), :class => "button")
    %(<div class="button-group">#{d*""}</div>).html_safe
  end
end
