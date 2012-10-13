# encoding: utf-8

require 'erb'

# A course has many professors, belongs to a semester and has a lot of
# tutors. The semantic could be a lecute, some seminar, tutorial etc.
class Course < ActiveRecord::Base
  belongs_to :semester, :inverse_of => :courses
  belongs_to :faculty, :inverse_of => :courses
  belongs_to :form, :inverse_of => :courses
  has_many :course_profs, :inverse_of => :course
  has_many :profs, :through => :course_profs
  has_many :c_pics, :through => :course_profs
  has_many :tutors, :inverse_of => :course
  validates_presence_of :semester_id, :title, :faculty, :language, :form
  validates_numericality_of :students, :allow_nil => true

  # finds all courses that contain all given keywords in their title.
  # The keywords must not appear in order. Only the first 10 keywords
  # are considered, Only alpha numerical characters and hyphens are
  # valid, all other characters are discarded. You can specify which
  # additional classes to include in order to speed things up using
  # the inc variable. An array is expected. Use cond and vals to specify
  # additional search criteria. For example, to limit to certain
  # semesters, you would specify: cond="semester_id IN (?)"  vals=[1,4]
  # You can also sort by passing an array of attributes to sorty by.
  def self.search(term, inc = [], cond = [], vals = [], order = nil)
    return Course.filter(inc, cond, vals, order) if term.nil?
    c = term.gsub(/[^a-z0-9-]/i, " ").split(/\s+/).map { |t| "%#{t}%" }[0..9]
    return Course.filter(inc, cond, vals, order) if c.nil? || c.empty?
    cols = ["evaluator", "title", "description", "profs.surname", "profs.firstname"]
    qry = case ActiveRecord::Base.configurations[Rails.env]['adapter']
      when /^mysql/     then "CONCAT_WS(' ', #{cols*","}) LIKE ?"
      when "postgresql" then "ARRAY_TO_STRING(ARRAY[#{cols*","}], ' ')"
      # SQL standard as implemented by… nobody
      else "(#{cols.join(" || ' ' || ")}) LIKE ?"
    end
    cond += [qry]*c.size
    vals += c
    Course.filter(inc, cond, vals, order)
  end

  # filters the courses by the given SQL-statement in cond and the
  # values corresponding to the ? in vals. Specify an array of classes
  # to load as well in inc. Pass array of variables to sort by, if
  # wished.
  def self.filter(inc, cond, vals, order = nil)
    Course.find(:all, :include => inc, :conditions => [cond.join(" AND "), *vals], :order => order)
  end

  # Create an alias for this rails variable
  def comment; summary; end

  # Returns list of tutors sorted by name (instead of adding-order)
  def tutors_sorted
    tutors.sort { |x,y| x.abbr_name.casecmp(y.abbr_name) }
  end

  # storing symbols via activerecord is a bit icky
  def language #:nodoc
    return '' if read_attribute(:language).nil?
    read_attribute(:language).to_sym
  end

  def language= (value)
    write_attribute(:language, value.to_s)
  end

  # translates a given string or symbol using the globla I18n system
  def t(string)
    I18n.t(string)
  end

  # returns if the course is critical. If it is, some features should
  # be disabled (e.g. deletion). A course is critical, when the semester
  # it belongs to is.
  def critical?
    semester.critical? || returned_sheets > 0
  end

  # Tries to parse the description field for eval times and returns them
  # in a nice format for string comparison (i.e. <=>)
  def eval_date
    # FIXME: Make pref?
    h = Hash["mo", 1, "di", 2, "mi", 3, "do", 4, "fr", 5, "???", 6]
    h.merge(Hash["mo", 1, "tu", 2, "we", 3, "th", 4, "fr", 5, "???", 6])
    a = description.strip.downcase
    a = "???" if a.length < 3 || !h.include?(a[0..1])
    day = h[a[0..1]]
    time = a[2..a.length-1].strip.rjust(3, "0")
    "#{day} #{time}"
  end

  # returns a newline seperated list of profs of this course
  def nl_separated_prof_fullname_list
    profs.map { |p| p.fullname + "\n" }.sort
  end

  # lovely helper function: we want to guess the mail address of
  # evaluators from their name, simply by adding a standand mail
  # domain to it. Returns comma separated list.
  def fs_contact_addresses
    fs_contact_addresses_array.join(',')
  end

  # lovely helper function: we want to guess the mail address of
  # evaluators from their name, simply by adding a standand mail
  # domain to it. Returns array
  def fs_contact_addresses_array
    pre_format = fscontact.blank? ? evaluator : fscontact

    pre_format.split(',').map do |a|
      (a =~ /@/ ) ? a : a + '@' + SCs[:standard_mail_domain]
    end
  end

  # Same as above, but do not include the default domain. Intended for
  # display where “user@“ is sufficient to know what the address is.
  def fs_contact_addresses_short
    fs_contact_addresses.gsub(/#{SCs[:standard_mail_domain]}$/, "")
  end

  def barcodes_with_checksum
    course_profs.map { |cp| cp.barcode_with_checksum }
  end

  # Returns array of integer-barcodes that belong to this course. It is
  # actually an array of the id of the course_prof class.
  def barcodes
    course_profs.map { |cp| cp.id }
  end

  # will count the returned sheets if all necessary data is available.
  # In case of an error, -1 will be returned.
  def returned_sheets
    return 0 if profs.empty?
    RT.count(form.db_table, {:barcode => barcodes})
  end

  # returns true if there have been sheets returned.
  def returned_sheets?
    returned_sheets > 0
  end

  # the head per course. this adds stuff like title, submitted
  # questionnaires, what kind of people submitted questionnaires etc
  def eval_lecture_head
    b = ""
    b << "\\kurskopf{#{title.escape_for_tex}}"
    b << "{#{profs.map { |p| p.fullname.escape_for_tex }.join(' / ')}}"
    b << "{#{returned_sheets}}"
    b << "{#{id}}"
    b << "{#{t(:by)}}\n\n"
    unless note.nil? || note.strip.empty?
      b << RT.small_header(I18n.t(:note))
      b << note.strip
      b << "\n\n"
    end
    b
  end

  # evaluates the given questions in the scope of this course.
  def eval_block(questions, section)
    b = RT.include_form_variables(self)
    b << RT.small_header(section)
    questions.each do |q|
      b << RT.eval_question(form.db_table, q,
            {:barcode => barcodes},
            {:barcode => faculty.barcodes},
            self)
    end
    b
  end

  # evaluates this whole course against the associated form. if single
  # is set, include headers etc.
  def evaluate(single=nil)
    puts "   #{title}"

    # if this course doesn't have any lecturers it cannot have been
    # evaluated, since the sheets are coded with the course_prof id
    # Return early to avoid problems.
    if profs.empty?
      warn "  #{title}: no profs -- skipping"
      return ""
    end

    I18n.locale = language if I18n.tainted? or single


    b = "\n\n\n% #{title}\n"

    if single
      evalname = title.escape_for_tex
      b << ERB.new(RT.load_tex("preamble")).result(binding)
      b << RT.load_tex_definitions
      b << '\maketitle' + "\n\n"
      facultylong = faculty.longname
      sem_title = { :short => semester.title, :long => semester.longtitle }
      b << ERB.new(RT.load_tex("preface")).result(binding)
    end

    b << "\\selectlanguage{#{I18n.t :tex_babel_lang}}\n"
    b << eval_lecture_head

    if returned_sheets < SCs[:minimum_sheets_required]
      b << form.too_few_sheets(returned_sheets)
      if single
        b << RT.sample_sheets_and_footer([form])
      end
      return b
    end

    # walk all questions, one section at a time. May split sections into
    # smaller groups if they belong to a different entity (i.e. repeat_
    # for attribute differs)
    form.sections.each do |section|
      questions = Array.new(section.questions)
      # walk all questions in this section
      while !questions.empty?
        # find all questions in this sections until repeat_for changes
        repeat_for = questions.first.repeat_for
        block = []
        while !questions.empty? && questions.first.repeat_for == repeat_for
          block << questions.shift
        end
        # now evaluate that block of questions according to it’s
        # repeat_for/belong_to value
        s = section.any_title
        case repeat_for
          when :course
            b << eval_block(block, s)
          when :lecturer
            course_profs.each { |cp| b << cp.eval_block(block, s) }
          when :tutor
            tutors_sorted.each { |t| b << t.eval_block(block, s) }
          else
            raise "Unimplemented repeat_for type #{repeat_for}"
        end
      end
    end

    if single
      b << RT.sample_sheets_and_footer([form])
    end

    return b
  end

  def dir_friendly_title
    ActiveSupport::Inflector.transliterate(title.strip).gsub(/[^a-z0-9_-]/i, '_')
  end

  private
  # quick access to some variables and classes
  SCs = Seee::Config.settings
end
