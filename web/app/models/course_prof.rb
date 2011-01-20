
class CourseProf < ActiveRecord::Base
  belongs_to :course
  belongs_to :prof
  has_many :c_pics

  include FunkyDBBits

  # eval and output
  def evaluate!
    puts evaluate
  end

  # evals sth against some form \o/
  # returns a TeX-string
  def evaluate
    form = course.form
    # setup for FunkyDBBits ...
    @db_table = form.db_table

    b = ''

    sheet_count = count_forms({:barcode => barcode.to_i})

    vorlhead = form.lecturer_header(prof.fullname, prof.gender, course.language, sheet_count)
    b << "\\profkopf{#{vorlhead}}\n\n"

    if sheet_count < Seee::Config.settings[:minimum_sheets_required]
      return b + form.too_few_questionnaires(course.language, sheet_count) + "\n\n"
    end

    # b << "\\fragenzurvorlesung\n\n"

    specific = { :barcode => barcode.to_i }
    general = { :barcode => $facultybarcodes }
    form.questions.find_all{ |q| q.section == 'prof' }.each do |q|
      b << q.eval_to_tex(specific, general, form.db_table, course.language)
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
    [course.form.name, course.title, prof.fullname, course.students.to_s + 'pcs'].join(' - ')
  end
end
