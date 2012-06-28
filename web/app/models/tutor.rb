# encoding: utf-8

# tutors belong to a course.
class Tutor < ActiveRecord::Base
  belongs_to :course, :inverse_of => :tutors
  has_many :pics, :inverse_of => :tutor
  has_one :form, :through => :course
  has_one :faculty, :through => :course
  has_one :semester, :through => :course

  validates_presence_of :abbr_name
  validates_uniqueness_of :abbr_name, :scope => :course_id, \
    :message => "Tutor already exists for this course."

  include FunkyTeXBits

  # returns if the tutor is critical. This is the case when either the
  # parent course is critical or if the course has returned sheets
  def critical?
    course.critical? || course.returned_sheets > 0
  end

  # Evaluates this tutor only.
  def evaluate
    I18n.locale = course.language

    b = RT.load_tex_definitions
    b << "\\selectlanguage{#{I18n.t :tex_babel_lang}}\n"
    b << course.eval_lecture_head

    if returned_sheets <= SCs[:minimum_sheets_required]
      b << form.too_few_sheets(returned_sheets)
      return b
    end

    # walk all questions, one section at a time. Simplified version of
    # the same loop in courses.rb#evaluate. Only one tutor is relevant
    # here.
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

        # now evaluate that block of questions
        if repeat_for == :tutor
          s = section.any_title
          b << eval_block(block, s)
        end
      end
    end

    return b
  end

  def eval_block(questions, section)
    b = RT.include_form_variables(self)
    # may be used to reference a specific tutor. For example, the tutor_
    # overview visualizer does this.
    b << RT.small_header(section)
    b << "\\label{tutor#{self.id}}\n"
    if returned_sheets < SCs[:minimum_sheets_required]
      b << form.too_few_sheets(returned_sheets)
      return b
    end

    tut_db_col = form.get_tutor_question.db_column.to_sym

    questions.each do |q|
      b << RT.eval_question(form.db_table, q,
            # this tutor only
            {:barcode => course.barcodes, tut_db_col => tutnum},
            # all tutors available
            {:barcode => faculty.barcodes},
            self)
    end
    b
  end

  def tutnum
    course.tutors.index(self) + 1
  end

  # will count the returned sheets if all necessary data is available.
  # In case of an error, -1 will be returned.
  def returned_sheets
    return 0 if course.profs.empty? || form.get_tutor_question.nil?
    tutor_db_column = form.get_tutor_question.db_column.to_sym
    RT.count(form.db_table, {:barcode => course.barcodes, \
      tutor_db_column => tutnum})
  end

  private
  # quick access to some variables and classes
  SCs = Seee::Config.settings
end
