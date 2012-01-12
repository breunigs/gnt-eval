# tutors belong to a course.
class Tutor < ActiveRecord::Base
  belongs_to :course
  has_many :pics
  has_one :form, :through => :course

  validates_presence_of :abbr_name
  validates_uniqueness_of :abbr_name, :scope => :course_id, \
    :message => "Tutor already exists for this course."

  include FunkyDBBits
  include FunkyTeXBits

  # returns if the tutor is critical. This is the case when either the
  # parent course is critical or if the course has returned sheets
  def critical?
    course.critical? || course.returned_sheets > 0
  end

  def eval_block(questions, section)
    # FIXME
    ""
  end

  def evaluate
    form = course.form
    @db_table = form.db_table

    b = "\\section{#{abbr_name}}\n\\label{#{id}}\n"

    # only set locale if we want a mixed-lang document
    I18n.locale = course.language if I18n.tainted?

    if sheet_count < Seee::Config.settings[:minimum_sheets_required]
      b << form.too_few_questionnaires(I18n.locale, sheet_count)
      b << "\n\n"
      return b, sheet_count
    end

    b << I18n.t(:submitted_questionnaires) + ': ' + sheet_count.to_s + "\n\n"
    tutor_db_column = course.form.get_tutor_question.db_column.to_sym

    specific = { :barcode => course.barcodes, tutor_db_column => tutnum }
    general = { :barcode => course.barcodes }
    form.questions.find_all{ |q| q.section == 'tutor' }.each do |q|
      next if q.type == "tutor_table"
      b << q.eval_to_tex(specific, general, form.db_table, I18n.locale)
    end
    unless comment.to_s.strip.empty?
      b << "\\textbf{#{I18n.t(:comments)}}\n\n"
      b << comment.to_s
    end
    return b, sheet_count
  end

  def tutnum
    course.tutors.index(self) + 1
  end

  def sheet_count
    warn "DEPRECATED: tutor#sheet_count is deprecated. Please use returned_sheets instead."
    # Otherwise the SQL query will not work
    return 0 if course.profs.empty?
    @db_table = course.form.db_table
    tutor_db_column = course.form.get_tutor_question.db_column.to_sym
    count_forms({:barcode => course.barcodes, tutor_db_column => tutnum})
  end

  # will count the returned sheets if all necessary data is available.
  # In case of an error, -1 will be returned.
  def returned_sheets
    return 0 if course.profs.empty?
    tutor_db_column = form.get_tutor_question.db_column.to_sym
    RT.count(form.db_table, {:barcode => course.barcodes, \
      tutor_db_column => tutnum})
  end

  private
  # quick access to some variables and classes
  RT = ResultTools.instance
  SCs = Seee::Config.settings
end
