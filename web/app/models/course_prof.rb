# encoding: utf-8


class CourseProf < ActiveRecord::Base
  belongs_to :course, :inverse_of => :course_profs
  belongs_to :prof, :inverse_of => :course_profs
  has_many :c_pics, :inverse_of => :course_prof
  # shortcuts
  has_one :form, :through => :course
  has_one :faculty, :through => :course
  has_one :term, :through => :course
  # import some features from other classes
  delegate :gender, :gender=, :to => :prof

  # will count the returned sheets if all necessary data is available.
  # In case of an error, -1 will be returned.
  def returned_sheets
    raise "No valid form associated." if form.nil?
    RT.count(form.db_table, {:barcode => id})
  end

  # returns true if sheets have been returned.
  def returned_sheets?
    returned_sheets > 0
  end

  # returns true if currently rendering/printing. This only applies to
  # jobs started from the web interface. Will return false once the job
  # has been submitted via lpr.
  def print_in_progress?
    !@print_in_progress.nil? && @print_in_progress
  end

  # set to true before starting a print job to prevent collisions. Reset
  # afterwards.
  def print_in_progress=(val)
    @print_in_progress = val ? true : false
  end

  # prints the form for this CourseProf. Optionally give an amount,
  # otherwise it will print as many sheets as there are students.
  # Returns the exit status of the printing application.
  def print_execute(amount = nil)
    raise "Invalid amount" unless amount.nil? || amount.to_s.match(/^[0-9]+$/)

    print_in_progress = true
    pdf_path = temp_dir("print_forms")

    # ensure the howtos exist
    #create_howtos(temp_dir("howtos"), pdf_path)

    # create form
    make_pdf_for(self, pdf_path)
    # print!
    p = Seee::Config.application_paths[:print]
    # prevent actual printing in test mode
    p << %( --simulate ) if ENV['RAILS_ENV'] == "test"
    p << %( --no-howtos )
    p << %( --amount=#{amount} ) if amount
    p << %( --non-interactive ")
    p << File.join(pdf_path, get_filename)
    p << %(.pdf")
    logger.debug "Command line used for printing:"
    logger.debug p
    `#{p}`
    exit_status = $?.exitstatus

    # run once again, so all newly created files are accessible by
    # everyone
    temp_dir
    print_in_progress = false
    exit_status
  end


  # evaluates the given questions in the scope of this course and prof.
  def eval_block(questions, section, censor)
    b = RT.include_form_variables(self)
    b << RT.small_header(section)
    if returned_sheets < SCs[:minimum_sheets_required]
      b << form.too_few_sheets(returned_sheets)
      # a little magic to see if the header was personalized. If not,
      # add the lecturer’s name here:
      b << " (#{prof.fullname})" unless section.match(/\\lect/)
      return b
    end

    questions.each do |q|
      b << RT.eval_question(form.db_table, q,
            {:barcode => id},
            {:barcode => faculty.barcodes},
            self,
            censor && !prof.publish_ok?)
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
    x = [course.form.name, course.language, course.title, prof.fullname, \
      course.students.to_s + 'pcs'].join(' - ').gsub(/\s+/,' ')
    x = ActiveSupport::Inflector.transliterate(x)
    x.gsub(/[^a-z0-9_.,:\s\-()]/i, "_")
  end

  private
  # quick access to some variables or classes
  SCs = Seee::Config.settings
end
