# tutors belong to a course.
class Tutor < ActiveRecord::Base
  belongs_to :course
  has_many :pics
  include FunkyDBBits
  include FunkyTeXBits

  # returns if the tutor is critical. This is the case when either the
  # parent course is critical or if the course has returned sheets
  def critical?
    course.critical? || course.returned_sheets > 0
  end

  def evaluate
    form = course.form
    @db_table = form.db_table

    b = "\\section{#{abbr_name}}\n\\label{#{id}}\n"

    if sheet_count < Seee::Config.settings[:minimum_sheets_required]
      b << form.too_few_questionnaires(course.language, sheet_count)
      b << "\n\n"
      return b, sheet_count
    end
    # only set locale if we want a mixed-lang document
    I18n.locale = course.language if I18n.tainted?
    b << I18n.t(:submitted_questionnaires) + ': ' + sheet_count.to_s + "\n\n"

    specific = { :barcode => course.barcodes, :tutnum => tutnum }
    general = { :barcode => course.barcodes }
    form.questions.find_all{ |q| q.section == 'tutor' }.each do |q|
      b << q.eval_to_tex(specific, general, form.db_table, course.language)
    end
    unless comment.to_s.strip.empty?
      b << "\\commentstutor{#{I18n.t(:comments)}}"
      b << comment.to_s
    end
    return b, sheet_count
  end

  def tutnum
    course.tutors.sort{ |x,y| x.id <=> y.id }.index(self) + 1
  end

  def competence
    @db_table = course.form.db_table
    competence_field = 'AVG(t2)'
    query(competence_field, { :barcode => course.barcodes, :tutnum => tutnum}, " AND t2 > 0").to_f
  end

  def profit
    @db_table = course.form.db_table
    profit_field = 'AVG(t10)'
    query(profit_field, { :barcode => course.barcodes, :tutnum => tutnum}, " AND t10 > 0").to_f

  end

  def teacher
    @db_table = course.form.db_table
    teacher_field = 'AVG(t1)'
    query(teacher_field, { :barcode => course.barcodes, :tutnum => tutnum}, " AND t1 > 0").to_f

  end
  def preparation
    @db_table = course.form.db_table
    prep_field = 'AVG(t3)'
    query(prep_field, { :barcode => course.barcodes, :tutnum => tutnum}, " AND t3 > 0").to_f

  end
  def sheet_count
    # Otherwise the SQL query will not work
    return 0 if course.profs.empty?
    @db_table = course.form.db_table
    count_forms({:barcode => course.barcodes, :tutnum => tutnum})
  end
end
