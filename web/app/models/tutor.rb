# tutors belong to a course.
class Tutor < ActiveRecord::Base
  belongs_to :course
  has_many :pics
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

  def eval_block(questions, section)
    b = RT.include_form_variables(self)
    # may be used to reference a specific tutor. For example, the tutor_
    # overview visualizer does this.
    b << "\\label{tutor#{self.id}}\n"
    b << RT.small_header(section)
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
  RT = ResultTools.instance
  SCs = Seee::Config.settings
end
