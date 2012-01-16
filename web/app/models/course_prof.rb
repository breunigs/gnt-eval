
class CourseProf < ActiveRecord::Base
  belongs_to :course
  belongs_to :prof
  has_many :c_pics
  # shortcuts
  has_one :form, :through => :course
  has_one :faculty, :through => :course
  # import some features from other classes
  delegate :gender, :gender=, :to => :prof

  include FunkyDBBits

  # will count the returned sheets if all necessary data is available.
  # In case of an error, -1 will be returned.
  def returned_sheets
    RT.count(form.db_table, {:barcode => id})
  end


  # evaluates the given questions in the scope of this course and prof.
  def eval_block(questions, section)
    b = RT.include_form_variables(self)
    b << RT.small_header(section)
    if returned_sheets < SCs[:minimum_sheets_required]
      b << form.too_few_sheets(returned_sheets)
    end

    questions.each do |q|
      b << RT.eval_question(form.db_table, q,
            {:barcode => id},
            {:barcode => faculty.barcodes},
            self)
    end
    b
  end

  # evals sth against some form \o/
  # returns a TeX-string
  def evaluate
    form = course.form
    # setup for FunkyDBBits ...
    # FIXME DEPRECATED
    @db_table = form.db_table

    b = ''

    # only set locale if we want a mixed-lang document
    I18n.locale = course.language if I18n.tainted?

    sheet_count = count_forms({:barcode => barcode.to_i})
    vorlhead = form.lecturer_header(prof.fullname, prof.gender, I18n.locale, sheet_count)
    b << "\\profkopf{#{vorlhead}}\n\n"

    if sheet_count < SCs[:minimum_sheets_required]
      return b + form.too_few_questionnaires(I18n.locale, sheet_count) + "\n\n"
    end

    # b << "\\fragenzurvorlesung\n\n"

    specific = { :barcode => barcode.to_i }
    general = { :barcode => faculty.barcodes }
    form.questions.find_all{ |q| q.section == 'prof' }.each do |q|
      b << q.eval_to_tex(specific, general, form.db_table, I18n.locale, prof.gender)
    end

    return b
  end

  def barcode
    return "%07d" % id
  end

  def barcode_with_checksum
    long_number = barcode.to_s
    sum = 0
    (0..6).each do |i|
      weight = 1 + 2*((i+1)%2)
      sum += weight*long_number[i,1].to_i
    end
    long_number + ((sum.to_f/10).ceil*10-sum).to_s
  end

  # shortform for barcode_with_checksum.to_i
  def i_bcwc
    barcode_with_checksum.to_i
  end


  # Returns a pretty unique name for this CourseProf
  def get_filename
    [course.form.name, course.language, course.title, prof.fullname, course.students.to_s + 'pcs'].join(' - ')
  end

  private
  # quick access to some variables or classes
  RT = ResultTools.instance
  SCs = Seee::Config.settings
end
