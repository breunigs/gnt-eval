# -*- coding: utf-8 -*-

# A course has many professors, belongs to a semester and has a lot of
# tutors. The semantic could be a lecute, some seminar, tutorial etc.
class Course < ActiveRecord::Base
  belongs_to :semester
  belongs_to :faculty
  has_many :course_profs
  has_many :profs, :through => :course_profs
  has_many :tutors
  validates_presence_of :semester_id
  validates_numericality_of :students

  include FunkyDBBits

  def form_id_to_name
    {3 => 'Seminarbogen',
     2 => 'Englischer Bogen',
     1 => 'Spezialbogen',
     0 => 'Normaler Bogen'}
  end

  def form_name_to_id
    hash = {}
    form_id_to_name.each_pair { |k,v| hash[v] = k }
    hash
  end

  def fs_contact_addresses
    if fscontact.empty?
      pre_format = evaluator
    else
      pre_format = fscontact
    end

    pre_format.split(',').map{ |a| (a =~ /@/ ) ? a : a + '@mathphys.fsk.uni-heidelberg.de'}.join(',')
  end

  def barcodes_with_checksum
    course_profs.map { |cp| cp.barcode_with_checksum }
  end

  def eval_against_form(form, dbh)
    b = ''

    # setup for FunkyDBBits
    @dbh = dbh
    @db_table = form.db_table

    this_eval = faculty.longname + ' ' + semester.title

    barcodes = course_profs.map{ |cp| cp.barcode.to_i}

    boegenanzahl = count_forms({ :barcode => barcodes})
    return '' if boegenanzahl == 0

    puts "   #{title}"
    isEn = form.isEnglish? ? "E" : "D"
    notspecified = (form.isEnglish? ? "not specified" : "keine Angabe")
    b << "\\kurskopf#{isEn}{#{title}}{#{profs.map { |p| p.fullname }.join(' / ')}}{#{boegenanzahl}}{#{id}}\n\n"

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
    # FIXME: Get directly from TeX?
    if form.isEnglish?
      matchn = [notspecified, "Mathematics", "Physics", "Comp. Sc."]
      matchm = ["", "Diploma", "Edu. Degree", "Bachelor" , "Master", "Ph.D."]
    else
      matchn = [notspecified, "Mathematik", "Physik", "Informatik"]
      matchm = ["", "Diplom", "Lehramt", "Bachelor" , "Master", "Promotion"]
    end
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
    b << (form.isEnglish? ? "other" : "Sonstige") + ": & " + (boegenanzahl-all).to_s + "\\\\ \n"  if boegenanzahl != all
    b << notspecified + ": & " + (keinang).to_s + "\\\\ \n" if keinang > 0
    b << "\\end{tabular}\\hfill\\null\n\n"

    # vorlesungseval pro dozi
    course_profs.each do |cp|
      b << cp.eval_against_form(form, dbh).to_s
    end

    b << "\\zusammenfassung{" + (form.isEnglish? ? "Comments" : "Kommentare" ) + "}$~~$ \\\\ " # $~~$ is pseudo-text so LaTeX actually breaks after this title
    b << summary.to_s
    b << "\n\\medskip\n\n"

    # uebungen allgemein, immer alles relativ zur fakultät!
    ugquest = form.questions.find_all{ |q| q.section == 'uebungsgruppenbetrieb'}
    return b if ugquest.empty?

    b << "\\fragenzudenuebungen{"+ (form.getStudyGroupsHeader) +"}\n"
    specific = { :barcode => barcodes }
    general = { :barcode => $facultybarcodes }
    ugquest.each do |q|
      b << q.eval_to_tex(specific, general, form.db_table, @dbh).to_s
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
      text, anz = t.eval_against_form(form, dbh)
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

  def evaluate(dbh)
    eval_against_form(form.to_form, dbh)
  end

end

class Integer
  def to_form
    p = File.join(File.dirname(__FILE__), "..", '/lib/forms/' + self.to_s + '.yaml')
    YAML::load(File.read(p))
  end
end
