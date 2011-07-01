# -*- coding: utf-8 -*-

require 'erb'

# A course has many professors, belongs to a semester and has a lot of
# tutors. The semantic could be a lecute, some seminar, tutorial etc.
class Course < ActiveRecord::Base
  belongs_to :semester
  belongs_to :faculty
  belongs_to :form
  has_many :course_profs
  has_many :profs, :through => :course_profs
  has_many :tutors
  validates_presence_of :semester_id, :title, :faculty, :language, :form
  validates_numericality_of :students

  include FunkyDBBits

  # storing symbols via activerecord is a bit icky
  def language #:nodoc
    return '' if read_attribute(:language).nil?
    read_attribute(:language).to_sym
  end

  def language= (value)
    write_attribute(:language, value.to_s)
  end

  # magic translator function
  def t(string)
    I18n.t(string)
  end

  # returns if the course is critical. If it is, some features should
  # be disabled (e.g. deletion). A course is critical, when the semester
  # it belongs to is.
  def critical?
    semester.critical?
  end

  # Tries to parse the description field for eval times and returns them
  # in a nice format for string comparison (i.e. <=>)
  def eval_date
    # FIXME: Make pref?
    h = Hash["mo", 1, "di", 2, "mi", 3, "do", 4, "fr", 5, "???", 6]
    h.merge(Hash["mo", 1, "tu", 2, "we", 3, "th", 4, "fr", 5, "???", 6])
    a = description.strip.downcase
    a = "???" if a.length < 3 || !h.include?(a[0..1])
    day = h[a[0..1]]
    time = a[2..a.length-1].strip.rjust(3, "0")
    "#{day} #{time}"
  end

  # returns a newline seperated list of profs of this course
  def nl_separated_prof_fullname_list
    profs.map { |p| p.fullname + "\n" }.sort
  end

  # lovely helper function: we want to guess the mail address of
  # evaluators from their name, simply by adding a standand mail
  # domain to it
  def fs_contact_addresses
    if fscontact.empty?
      pre_format = evaluator
    else
      pre_format = fscontact
    end

    pre_format.split(',').map{ |a| (a =~ /@/ ) ? a : a + '@' + Seee::Config.settings[:standard_mail_domain]}.join(',')
  end

  def barcodes_with_checksum
    course_profs.map { |cp| cp.barcode_with_checksum }
  end

  def barcodes
    course_profs.map{ |cp| cp.barcode.to_i }
  end

  # will count the returned sheets, if all necessary data is
  # available. In case of an error, -1 will be returned.
  def returned_sheets
    return -1 if form.nil? || form.db_table.nil?
    @db_table = form.db_table

    if not profs.empty?
      count_forms({ :barcode => barcodes})
    else
      return 0
    end
  end

  # the head per course. this adds stuff like title, submitted
  # questionnaires, what kind of people submitted questionnaires etc
  def eval_lecture_head
    b = ""

    sheets = returned_sheets

    notspecified = t(:not_specified)
    b << "\\kurskopf{#{title}}{#{profs.map { |p| p.fullname }.join(' / ')}}{#{sheets}}{#{id}}{#{t(:by)}}{#{t(:submitted_questionnaires)}}\n\n"
    b << "\\begin{multicols}{2}"


    data = IO.read(RAILS_ROOT + "/../tex/results_horiz_bars.tex.erb")

    # semesterdistribution #############################################
    lang_sem = t(:academic_term)
    sems = get_distinct_values("semester", {:barcode => barcodes}).sort

    lines = []
    (sems-[0]).each do |i|
      num = count_forms({:barcode => barcodes, :semester => i})
      lines << {:name => "#{i == 16 ? "> 15" : i}. #{lang_sem}",
        :count => num }
    end
    num = count_forms({:barcode => barcodes, :semester => 0})
    lines << {:name => notspecified, :count => num}

    title = t('semester_distribution')
    b << ERB.new(data).result(binding)
    b << "\\columnbreak"

    # degree ###########################################################
    lines = []

    # grab the description text for each checkbox from the form
    matchn = [notspecified] + form.get_question("hauptfach").get_choices(language)
    matchm = [""] + form.get_question("studienziel").get_choices(language)
    # remove "sonstiges" or "other" from the end of the array because
    # otherwise we get pretty useless combinations
    matchn.pop
    matchm.pop

    all = 0
    keinang = 0
    0.upto(matchn.length) do |n|
      0.upto(matchm.length) do |m|
        num = count_forms({:barcode => barcodes, :hauptfach => n, :studienziel => m})
        # skip all entries with very few votes
        next if num/sheets.to_f*100 < 2
        all += num
        # check for 'other' and skip
        next if n == matchn.length || m == matchm.length

        # check for 'not specified' and group them together
        if n == 0 || m == 0
          keinang += num
          next
        end
        lines << {:name => matchn[n] + " " + matchm[m], :count => num }
      end
    end
    lines.sort! { |x,y| y[:count] <=> x[:count] }
    lines << {:name => t(:other), :count => sheets-all } if sheets != all
    lines << {:name => notspecified, :count => keinang } if keinang > 0

    title = t(:degree_course)
    b << ERB.new(data).result(binding)

    b << "\\end{multicols}"

    b
  end

  # eval me (baby)
  def evaluate
    # if this course doesn't have any lecturers it cannot have been
    # evaluated, since the sheets are coded with the course_prof id
    # Return early to avoid problems.
    return "" if profs.empty?

    I18n.locale = language if I18n.tainted?
    I18n.load_path += Dir.glob(File.join(Rails.root, '/config/locales/*.yml'))

    b = ''

    # setup for FunkyDBBits
    @db_table = form.db_table

    puts "   #{title}"
    b << eval_lecture_head

    # lecture eval per lecturer
    course_profs.each do |cp|
      b << cp.evaluate.to_s
    end

    # Do not print a "too few sheets" message here because if there are
    # too few sheets, it will have been printed for at least one lecturer
    # above already.
    if returned_sheets >= Seee::Config.settings[:minimum_sheets_required]
      unless summary.to_s.strip.empty?
        b << "\\commentsprof{#{t(:comments)}}\n\n"
        b << t(:notice_for_comments)
        b << "\n\n"
        b << summary.to_s
        b << "\n\\medskip\n\n"
      end

      # uebungen allgemein, immer alles relativ zur fakultät!
      ugquest = form.questions.find_all{ |q| q.section == 'uebungsgruppenbetrieb'}
      return b if ugquest.empty?

      b << "\\fragenzudenuebungen{"+ I18n.t(:study_groups_header) +"}\n"
      specific = { :barcode => barcodes }
      general = { :barcode => $facultybarcodes }
      ugquest.each do |q|
        b << q.eval_to_tex(specific, general, form.db_table, language).to_s
      end
    end

    return b if tutors.empty?

    c = ''
    c << "\\uebersichtuebungsgruppen{"+I18n.t(:study_groups_overview)+"}\n"
    c << "\\begin{longtable}[l]{lrr}\n"
    c << "\\hline\n"
    c << I18n.t(:study_groups_overview_header) + " \\\\ \n"
    c << "\\hline\n"
    c << "\\endhead\n"
    cc = ''
    found = false
    tutors.sort{|x,y| x.abbr_name.casecmp(y.abbr_name) }.each do |t|
      text, anz = t.evaluate
      next if anz.nil?
      c << "\\hyperref[#{t.id}]{#{t.abbr_name}} & #{anz} & \\pageref{#{t.id}}\\\\ \n"
      cc << text.to_s
      found = true
    end
    return b unless found
    c << "\\hline\n"
    c << "\\end{longtable}"
    # only print table if there are at least two tutors
    b << c if tutors.size > 1
    b << cc

    return b
  end

end
