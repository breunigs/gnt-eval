
class CourseProf < ActiveRecord::Base
  belongs_to :course
  belongs_to :prof
  has_many :c_pics

  include FunkyDBBits

  # eval and output
  def eval_against_form!(form)
    puts eval_against_form(form)
  end

  # evals sth against some form \o/
  # returns a TeX-string
  def eval_against_form(form)

    # setup for FunkyDBBits ...
    @db_table = form.db_table

    b = ''
    this_eval = course.faculty.longname + ' ' + course.semester.title

    boegenanzahl = count_forms({:barcode => barcode.to_i})

    # FIXME: Shouldn't this be larger than 2?
    return '' unless boegenanzahl > 0

    vorlhead = form.getLecturerHeader(prof.fullname, prof.gender, boegenanzahl)
    b << "\\profkopf{#{vorlhead}}\n\n"
    # b << "\\fragenzurvorlesung\n\n"

    specific = { :barcode => barcode.to_i }
    general = { :barcode => $facultybarcodes }
    form.questions.find_all{ |q| q.section == 'prof' }.each do |q|
      b << q.eval_to_tex(specific, general, form.db_table)
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
    [course.title, prof.fullname, course.students.to_s + 'pcs'].join(' - ')
  end
end
