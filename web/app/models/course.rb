# -*- coding: utf-8 -*-

require 'erb'

# A course has many professors, belongs to a semester and has a lot of
# tutors. The semantic could be a lecute, some seminar, tutorial etc.
class Course < ActiveRecord::Base
  # by default, only work on courses in currently active semesters
  default_scope(:conditions => {:semester_id => Semester.currently_active})

  belongs_to :semester
  belongs_to :faculty
  belongs_to :form
  has_many :course_profs
  has_many :profs, :through => :course_profs
  has_many :tutors
  validates_presence_of :semester_id, :title, :faculty, :language, :form
  validates_numericality_of :students

  include FunkyDBBits

  # finds all courses that contain all given keywords in their title.
  # The keywords must not appear in order. Only the first 10 keywords
  # are considered, Only alpha numerical characters and hyphens are
  # valid, all other characters are discarded.
  def self.search(term)
    return Course.all if term.nil?
    c = term.gsub(/[^a-z0-9-]/i, " ").split(/\s+/).map { |t| "%#{t}%" }[0..9]
    return Course.all if c.nil? || c.empty?
    Course.find(:all, :conditions => [(["title LIKE ?"]*c.size).join(" AND "), *c])
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
  # domain to it
  def fs_contact_addresses
    pre_format = fscontact.empty? ? evaluator : fscontact

    pre_format.split(',').map do |a|
      (a =~ /@/ ) ? a : a + '@' + SCs[:standard_mail_domain]
    end.join(',')
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

  # the head per course. this adds stuff like title, submitted
  # questionnaires, what kind of people submitted questionnaires etc
  def eval_lecture_head
    b = ""

    sheets = returned_sheets

    notspecified = t(:not_specified)
    b << "\\kurskopf{#{title.escape_for_tex}}{#{profs.map { |p| p.fullname.escape_for_tex }.join(' / ')}}{#{sheets}}{#{id}}{#{t(:by)}}{#{t(:submitted_questionnaires)}}\n\n"
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

  # evaluates this whole course against the associated form
  def evaluate
    puts "   #{title}"

    # if this course doesn't have any lecturers it cannot have been
    # evaluated, since the sheets are coded with the course_prof id
    # Return early to avoid problems.
    if profs.empty?
      warn "  #{title}: no profs -- skipping"
      return ""
    end

    I18n.locale = language if I18n.tainted?

    b = "\n\n\n% #{title}\n"
    b << "\\selectlanguage{#{I18n.t :tex_babel_lang}}\n"
    b << eval_lecture_head

    if returned_sheets <= SCs[:minimum_sheets_required]
      b << form.too_few_sheets(returned_sheets)
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
          when :course:
            b << eval_block(block, s)
          when :lecturer:
            course_profs.each { |cp| b << cp.eval_block(block, s) }
          when :tutor:
            tutors_sorted.each { |t| b << t.eval_block(block, s) }
          else
            raise "Unimplemented repeat_for type #{repeat_for}"
        end
      end
    end

    return b
  end

  private
  # quick access to some variables and classes
  RT = ResultTools.instance
  SCs = Seee::Config.settings
end
