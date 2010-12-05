# -*- coding: utf-8 -*-

# A course has many professors, belongs to a semester and has a lot of
# tutors. The semantic could be a lecute, some seminar, tutorial etc.
class Course < ActiveRecord::Base
  belongs_to :semester
  belongs_to :faculty
  belongs_to :form
  has_many :course_profs
  has_many :profs, :through => :course_profs
  has_many :tutors
  validates_presence_of :semester_id
  validates_numericality_of :students

  include FunkyDBBits

  # def form_id_to_name
  #   {3 => 'Seminarbogen',
  #    2 => 'Englischer Bogen',
  #    1 => 'Spezialbogen',
  #    0 => 'Normaler Bogen'}
  # end

  # def form_name_to_id
  #   hash = {}
  #   form_id_to_name.each_pair { |k,v| hash[v] = k }
  #   hash
  # end

  # def form_name
  #   form_id_to_name[self.form] || "form #{self.form} doesn't exist"
  # end

  def form_name
    form.name
  end
  # def form_id
  #   self.form
  # end

  # Tries to parse the description field for eval times and returns them
  # in a nice format for string comparison (i.e. <=>)
  def eval_date
    # FIXME: Make pref?
    h = Hash["mo", 1, "di", 2, "mi", 3, "do", 4, "fr", 5, "???", 6]
    a = description.strip.downcase
    a = "???" if a.length < 3 || !h.include?(a[0..1])
    day = h[a[0..1]]
    time = a[2..a.length-1].strip.rjust(3, "0")
    "#{day} #{time}"
  end

  # returns a newline seperated list of profs of this course
  def prof_list
    profs.map { |p| p.fullname + "\n" }.sort
  end

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

  def getReturnedSheets
    @db_table = form.db_table

    if not profs.empty?
      count_forms({ :barcode => barcodes})
    else
      return 0
    end
  end

  def eval_lecture_head(form)
    b = ''

    sheets = getReturnedSheets

    isEn = form.isEnglish? ? "E" : "D"
    notspecified = (form.isEnglish? ? "not specified" : "keine Angabe")
    b << "\\kurskopf#{isEn}{#{title}}{#{profs.map { |p| p.fullname }.join(' / ')}}{#{sheets}}{#{id}}\n\n"

    # Semesterverteilung
    b << "\\hfill\\begin{tabular}[t]{lr}\n"
    b << "  \\multicolumn{2}{l}{\\textbf{"+(form.isEnglish? ? "semester distribution" : "Semesterverteilung" )+":}} \\\\[.2em]\n"

    lang_sem = form.isEnglish? ? "Academic Term" : "Fachsemester"

    # finds all different semesters for this course and counts them
    sems = get_distinct_values("semester", {:barcode => barcodes}).sort
    (sems-[0]).each do |i|
      num = count_forms({:barcode => barcodes, :semester => i})
      next if num == 0

      b << i.to_s + ". #{lang_sem}: & " + num.to_s + "\\\\ \n"
    end
    num = count_forms({:barcode => barcodes, :semester => 0})
    b << notspecified + ": & " + num.to_s + "\\\\ \n" if num > 0
    b << "\\end{tabular}\\hfill\n"

    # Hauptfach
    b << "\\begin{tabular}[t]{lr}\n"
    b << "  \\multicolumn{2}{l}{\\textbf{"+ (form.isEnglish? ? "degree course" : "Studiengänge") + ":}}\\\\[.2em]\n"

    # grab the description text for each checkbox from the form
    matchn = [notspecified] + form.get_question("hauptfach").get_choices
    matchm = [""] + form.get_question("studienziel").get_choices
    # remove "sonstiges" or "other" from the end of the array because
    # otherwise we get pretty useless combinations
    matchn.pop
    matchm.pop

    all = 0
    keinang = 0
    0.upto(matchn.length) do |n|
      0.upto(matchm.length) do |m|
        num = count_forms({:barcode => barcodes, :hauptfach => n, :studienziel => m})
        next if num == 0
        all += num
        # check for 'sonstige' and skip
        if n == matchn.length || m == matchm.length
          next
        end

        # check for 'keine Angabe' and group them together
        if n == 0 || m == 0
          keinang += num
          next
        end
        # print matches
        b << matchn[n] + " " + matchm[m] + ": & " + num.to_s + "\\\\ \n"
      end
    end
    b << (form.isEnglish? ? "other" : "Sonstige") + ": & " + (sheets-all).to_s + "\\\\ \n"  if sheets != all
    b << notspecified + ": & " + (keinang).to_s + "\\\\ \n" if keinang > 0
    b << "\\end{tabular}\\hfill\\null\n\n"

    b
  end

  def eval_against_form(form)
    # if this course doesn't have any lecturers it cannot have been
    # evaluated, since the sheets are coded with the course_prof id
    # Return early to avoid problems.
    return "" if profs.empty?

    b = ''

    # setup for FunkyDBBits
    @db_table = form.db_table

    puts "   #{title}"
    b << eval_lecture_head(form)

    # vorlesungseval pro dozi
    course_profs.each do |cp|
      b << cp.eval_against_form(form).to_s
    end

    # Do not print a "too few sheets" message here because if there are
    # to few sheets, it will have been printed for at least one lecturer
    # above already.
    if getReturnedSheets >= Seee::Config.settings[:minimum_sheets_required]
      unless summary.to_s.strip.empty?
        b << "\\commentsprof{#{form.isEnglish? ? "Comments" : "Kommentare"}}\n\n"
        b << "{ \\small\\emph{Hinweis:} Bei den Kommentaren handelt es sich um Einzelmeinungen, die immer in Relation zur Gesamthörerzahl gesetzt werden sollten.}\n\n" if !form.isEnglish?
        b << "{ \\small\\emph{Note: } Each comment is an individual opinion and should be considered in relation to the total number of students.}\n\n" if form.isEnglish?
        b << summary.to_s
        b << "\n\\medskip\n\n"
      end

      # uebungen allgemein, immer alles relativ zur fakultät!
      ugquest = form.questions.find_all{ |q| q.section == 'uebungsgruppenbetrieb'}
      return b if ugquest.empty?

      b << "\\fragenzudenuebungen{"+ (form.getStudyGroupsHeader) +"}\n"
      specific = { :barcode => barcodes }
      general = { :barcode => $facultybarcodes }
      ugquest.each do |q|
        b << q.eval_to_tex(specific, general, form.db_table).to_s
      end
    end

    return b if tutors.empty?

    c = ''
    c << "\\uebersichtuebungsgruppen{"+form.getStudyGroupsOverview+"}\n"
    c << "\\begin{longtable}[l]{lrr}\n"
    c << "\\hline\n"
    c << form.getStudyGroupsOverviewHeader + " \\\\ \n"
    c << "\\hline\n"
    c << "\\endhead\n"
    cc = ''
    found = false
    tutors.sort{|x,y| x.abbr_name.casecmp(y.abbr_name) }.each do |t|
      text, anz = t.eval_against_form(form)
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

  def evaluate
    eval_against_form(form.to_form)
  end

end

class Integer
  def to_form
    p = File.join(File.dirname(__FILE__), "..", '/lib/forms/' + self.to_s + '.yaml')
    # Cache YAML sheets in a global variable to avoid loading them again
    $loaded_yaml_sheets ||= {}
    $loaded_yaml_sheets[p] ||= YAML::load(File.read(p))
    $loaded_yaml_sheets[p]
  end
end
