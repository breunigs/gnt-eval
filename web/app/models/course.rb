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

  # Returns list of tutors sorted by name (instead of adding-order)
  def tutors_sorted
    tutors.sort { |x,y| x.abbr_name.casecmp(y.abbr_name) }
  end

  # storing symbols via activerecord is a bit icky
  def language #:nodoc
    return '' if read_attribute(:language).nil?
    read_attribute(:language).to_sym
  end

  def language= (value)
    write_attribute(:language, value.to_s)
  end

  # translates a given string or symbol using the globla I18n system
  def t(string)
    I18n.t(string)
  end

  # returns if the course is critical. If it is, some features should
  # be disabled (e.g. deletion). A course is critical, when the semester
  # it belongs to is.
  def critical?
    semester.critical? || returned_sheets > 0
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
    pre_format = fscontact.empty? ? evaluator : fscontact

    pre_format.split(',').map do |a|
      (a =~ /@/ ) ? a : a + '@' + Seee::Config.settings[:standard_mail_domain]
    end.join(',')
  end

  def barcodes_with_checksum
    course_profs.map { |cp| cp.barcode_with_checksum }
  end

  # Returns the array of barcodes that belong to this course. It is
  # actually a list of the id of the course_prof class.
  def barcodes
    course_profs.map{ |cp| cp.barcode.to_i }
  end

  # will count the returned sheets if all necessary data is available.
  # In case of an error, -1 will be returned.
  def returned_sheets
    return 0 if profs.empty?
    rt.count(form.db_table, {:barcode => barcodes})
  end

  # the head per course. this adds stuff like title, submitted
  # questionnaires, what kind of people submitted questionnaires etc
  def eval_lecture_head
    b = ""

    sheets = returned_sheets

    notspecified = t(:not_specified)
    b << "\\kurskopf{#{title.escape_for_tex}}{#{profs.map { |p| p.fullname.escape_for_tex }.join(' / ')}}{#{sheets}}{#{id}}{#{t(:by)}}{#{t(:submitted_questionnaires)}}\n\n"
    b << "\\begin{multicols}{2}"


    #~ data = IO.read(RAILS_ROOT + "/../tex/results_horiz_bars.tex.erb")
#~
    #~ # degree ###########################################################
    #~ lines = []
#~
    #~ # grab the description text for each checkbox from the form
    #~ # FIXME: don't hardcode this, but make it an attribute of the
    #~ #        question in Abstractform
    #~ matchn = [notspecified] + form.get_question("v_central_major").get_choices(I18n.locale)
    #~ matchm = [""] + form.get_question("v_central_degree").get_choices(I18n.locale)
    #~ # remove "sonstiges" or "other" from the end of the array because
    #~ # otherwise we get pretty useless combinations
    #~ matchn.pop
    #~ matchm.pop
#~
    #~ all = 0
    #~ keinang = 0
    #~ 0.upto(matchn.length) do |n|
      #~ 0.upto(matchm.length) do |m|
        #~ num = count_forms({:barcode => barcodes, :hauptfach => n, :studienziel => m})
        #~ # skip all entries with very few votes
        #~ next if num/sheets.to_f*100 < 2
        #~ # check for 'other' and skip
        #~ next if n == matchn.length || m == matchm.length
#~
        #~ all += num
#~
        #~ # check for 'not specified' and group them together
        #~ if n == 0 || m == 0
          #~ keinang += num
          #~ next
        #~ end
        #~ lines << {:name => matchn[n] + " " + matchm[m], :count => num }
      #~ end
    #~ end
    #~ lines.sort! { |x,y| y[:count] <=> x[:count] }
    #~ lines << {:name => t(:other), :count => sheets-all } if sheets-all > 0
    #~ lines << {:name => notspecified, :count => keinang } if keinang > 0
#~
    #~ title = t(:degree_course)
    #~ b << ERB.new(data).result(binding)
    #~ b << "\\columnbreak"

    # semesterdistribution #############################################
    #~ lang_sem = t(:academic_term)
    #~ sems = get_distinct_values("semester", {:barcode => barcodes}).sort
#~
    #~ lines = []
    #~ (sems-[0]).each do |i|
      #~ num = count_forms({:barcode => barcodes, :semester => i})
      #~ lines << {:name => "#{i == 16 ? "> 15" : i}. #{lang_sem}",
        #~ :count => num }
    #~ end
    #~ num = count_forms({:barcode => barcodes, :semester => 0})
    #~ lines << {:name => notspecified, :count => num}
#~
    #~ title = t('semester_distribution')
    #~ b << ERB.new(data).result(binding)
#~
    b << "\\end{multicols}"
    b
  end

  # evaluates the given questions in the scope of this course.
  def eval_block(questions, section)
    b = rt.small_header(section)
    questions.each do |q|
      b << rt.eval_question(form.db_table, q, {:barcode => barcodes}, {})
    end
    b
  end

  # evaluates this whole course against the associated form
  def evaluate
    puts "   #{title}"

    # if this course doesn't have any lecturers it cannot have been
    # evaluated, since the sheets are coded with the course_prof id
    # Return early to avoid problems.
    if profs.empty?
      puts "     no profs -- skipping"
      return ""
    end

    unless table_exists?(form.db_table)
      puts "     table #{form.db_table} does not exit yet -- skipping"
      return ""
    end

    I18n.locale = language if I18n.tainted?

    b = "\n\n\n% #{title}\n"
    b << "\\selectlanguage{#{I18n.t :tex_babel_lang}}\n"
    b << eval_lecture_head

    # walk all questions, one section at a time. May split sections into
    # smaller groups if they belong to a different entity (i.e. repeat_
    # for attribute differs)
    form.sections.each do |section|
      questions = Array.new(section.questions)
      # walk all questions in this section
      while !questions.empty?
        # find all questions in this sections until repeat_for changes
        repeat_for = questions.first.repeat_for
        block = []
        while !questions.empty? && questions.first.repeat_for == repeat_for
          block << questions.shift
        end
        # now evaluate that block of questions according to it’s
        # repeat_for/belong_to value
        s = section.any_title
        case repeat_for
          when :course:
            b << rt.include_form_variables(self)
            b << eval_block(block, s)
          when :lecturer:
            course_profs.each { |cp| b << cp.eval_block(block, s) }
          when :tutor:
            tutors_sorted.each { |t| b << t.eval_block(block, s) }
          else
            raise "Unimplemented repeat_for type #{repeat_for}"
        end
      end
    end


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

      c = ""
      specific = { :barcode => barcodes }
      general = { :barcode => $facultybarcodes }
      ugquest.each do |q|
        c << q.eval_to_tex(specific, general, form.db_table, I18n.locale).to_s
      end

      return b if c.strip.empty? && tutors.empty?

      b << "\\fragenzudenuebungen{"+ I18n.t(:study_groups_header) +"}\n"
      b << c
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

  private
  # quick access to ResultTools.instance
  def rt
    ResultTools.instance
  end

end
