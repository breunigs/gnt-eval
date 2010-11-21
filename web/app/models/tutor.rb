# tutors belong to a course.
class Tutor < ActiveRecord::Base
  belongs_to :course
  has_many :pics
  include FunkyDBBits
  include FunkyTeXBits

  def eval_against_form(form)
    @db_table = form.db_table

    b = "\\section{#{abbr_name}}\n\\label{#{id}}\n"

    if sheetcount < Seee::Config.settings[:minimum_sheets_required]
      b << form.getTooFewQuestionnaires(sheetcount)
      b << "\n\n"
      return b, sheetcount
    end

    b << "#{form.getSheetCount}: #{sheetcount}\n\n"

    specific = { :barcode => course.barcodes, :tutnum => tutnum }
    general = { :barcode => course.barcodes }
    form.questions.find_all{ |q| q.section == 'tutor' }.each do |q|
      b << q.eval_to_tex(specific, general, form.db_table)
    end
    unless comment.to_s.strip.empty?
      if form.isEnglish?
        b << "\\commentstutor{Comments}"
      else
        b << "\\commentstutor{Kommentare}"
      end
      b << comment.to_s
    end
    return b, sheetcount
  end

  def tutnum
    course.tutors.sort{ |x,y| x.id <=> y.id }.index(self) + 1
  end

  def competence
    @db_table = course.form.to_form.db_table
    competence_field = 'AVG(t2)'
    query(competence_field, { :barcode => course.barcodes, :tutnum => tutnum}, " AND t2 > 0").to_f
  end

  def profit
    @db_table = course.form.to_form.db_table
    profit_field = 'AVG(t10)'
    query(profit_field, { :barcode => course.barcodes, :tutnum => tutnum}, " AND t10 > 0").to_f

  end

  def teacher
    @db_table = course.form.to_form.db_table
    teacher_field = 'AVG(t1)'
    query(teacher_field, { :barcode => course.barcodes, :tutnum => tutnum}, " AND t1 > 0").to_f

  end
  def preparation
    @db_table = course.form.to_form.db_table
    prep_field = 'AVG(t3)'
    query(prep_field, { :barcode => course.barcodes, :tutnum => tutnum}, " AND t3 > 0").to_f

  end
  def sheetcount
    # Otherwise the SQL query will not work
    return 0 if course.profs.empty?
    @db_table = course.form.to_form.db_table
    count_forms({:barcode => course.barcodes, :tutnum => tutnum})
  end
end
