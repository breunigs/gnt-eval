
class CourseProf < ActiveRecord::Base
  belongs_to :course
  belongs_to :prof
  has_many :c_pics
  # shortcuts
  has_one :form, :through => :course
  has_one :faculty, :through => :course
  # import some features from other classes
  delegate :gender, :gender=, :to => :prof

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
      return b
    end

    questions.each do |q|
      b << RT.eval_question(form.db_table, q,
            {:barcode => id},
            {:barcode => faculty.barcodes},
            self)
    end
    b
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
  SCs = Seee::Config.settings
end
