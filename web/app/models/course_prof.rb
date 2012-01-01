
class CourseProf < ActiveRecord::Base
  belongs_to :course
  belongs_to :prof
  has_many :c_pics

  include FunkyDBBits

  def eval_block(questions, section)
    b = ""
    b << rt.include_form_variables(self)
    # FIXME
    ""
  end

  # will count the returned sheets if all necessary data is available.
  # In case of an error, -1 will be returned.
  def returned_sheets
    ResultTools.instance.count(course.form.db_table, {:barcode => id})
  end


  # evals sth against some form \o/
  # returns a TeX-string
  def evaluate
    form = course.form
    # setup for FunkyDBBits ...
    # FIXME DEPRECATED
    @db_table = form.db_table

    b = ''
    # head lecturer info into TeX so the questions may refer to them
    b << "\\def\\lectLast{#{prof.lastname.escape_for_tex}}"
    b << "\\def\\lect{#{prof.fullname.escape_for_tex}}"

    # only set locale if we want a mixed-lang document
    I18n.locale = course.language if I18n.tainted?

    sheet_count = count_forms({:barcode => barcode.to_i})
    vorlhead = form.lecturer_header(prof.fullname, prof.gender, I18n.locale, sheet_count)
    b << "\\profkopf{#{vorlhead}}\n\n"

    if sheet_count < Seee::Config.settings[:minimum_sheets_required]
      return b + form.too_few_questionnaires(I18n.locale, sheet_count) + "\n\n"
    end

    # b << "\\fragenzurvorlesung\n\n"

    specific = { :barcode => barcode.to_i }
    general = { :barcode => $facultybarcodes }
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
  # quick access to ResultTools.instance
  def rt
    ResultTools.instance
  end
end
