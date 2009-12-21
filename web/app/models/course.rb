# -*- coding: utf-8 -*-

# A course has many professors, belongs to a semester and has a lot of
# tutors. The semantic could be a lecute, some seminar, tutorial etc.
class Course < ActiveRecord::Base
  belongs_to :semester
  has_many :course_profs
  has_many :profs, :through => :course_profs
  has_many :tutors
  has_many :c_pics
  validates_presence_of :semester_id
  validates_numericality_of :students
  
  include FunkyDBBits
  
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
    
    this_eval = ['Mathematik', 'Physik'][faculty] + ' ' +
      semester.title 
      
    boegenanzahl = count_forms({ :barcode => course_profs.map{ |cp|
                                   cp.barcode.to_i}})
    return '' unless boegenanzahl > 0
    puts "   #{title}"
    b << "\\kurskopf{#{title}}{#{profs.map { |p| p.fullname }.join(' / ')}}{#{boegenanzahl}}\n\n"
    
    # Semesterverteilung
    b << "\\hfill\\begin{tabular}[t]{lr}\n"
    b << "  \\multicolumn{2}{l}{\\textbf{Semesterverteilung:}} \\\\[.2em]\n"
    # FIXME: get length automatically?
    1.upto(16) do |i|
      num = count_forms({:barcode => course_profs.map{ |cp| cp.barcode.to_i},
                                :semester => i}) 
      next if num == 0
      b << i.to_s + ". Fachsemester: & " + num.to_s + "\\\\ \n"
    end
    num = count_forms({:barcode => course_profs.map{ |cp| cp.barcode.to_i},
                                :semester => 0}) 
    b << "keine Angabe: & " + num.to_s + "\\\\ \n" if num > 0
    b << "\\end{tabular}\\hfill\n"
    
    # Hauptfach
    b << "\\begin{tabular}[t]{lr}\n"
    b << "  \\multicolumn{2}{l}{\\textbf{Studiengänge:}}\\\\[.2em]\n"
    # FIXME: Get directly from TeX?
    matchn = ["Mathematik", "Physik", "Informatik", "S"]
    matchm = ["Diplom", "Lehramt", "Bachelor" , "Master", "Promotion", "S"]
    all = 0
    sonst = 0
    1.upto(4) do |n|
      1.upto(6) do |m|
        num = count_forms({:barcode => course_profs.map{ |cp| cp.barcode.to_i},
                                :hauptfach => n, :studienziel => m}) 
        next if num == 0
        all += num
        # check for 'sonstige' and group them together
        if n == 4 || m == 6
          sonst += num
          next
        end
        # print matches
        b << matchn[n-1] + " " + matchm[m-1] + ": & " + num.to_s + "\\\\ \n"
      end
    end
    b << "Sonstige: & " + sonst.to_s + "\\\\ \n" if sonst > 0
    b << "keine Angabe: & " + (boegenanzahl-all).to_s + "\\\\ \n" if boegenanzahl != all
    b << "\\end{tabular}\\hfill\\null\n\n"
    
    b << "\\zusammenfassung\n"
    b << summary.to_s
    b << "\n\\medskip\n\n"
    
    # vorlesungseval pro dozi
    course_profs.each do |cp|
      b << cp.eval_against_form(form, dbh).to_s
    end
    
    # uebungen allgemein, immer alles relativ zur fakultät!
    ugquest = form.questions.find_all{ |q| q.section == 'uebungsgruppenbetrieb'}
    return b if ugquest.empty?
    
    b << "\\fragenzudenuebungen\n"
    specific = { :barcode => course_profs.map{ |cp| cp.barcode.to_i } }
    general = { :barcode => $facultybarcodes }
    ugquest.each do |q|
      b << q.eval_to_tex(specific, general, form.db_table, @dbh).to_s
    end
    
    return b if tutors.empty?

    c = ''
    c << "\\uebersichtuebungsgruppen\n"
    c << "\\begin{tabular}[b]{lr}\n"
    c << "\\hline\n"
    c << "Tutor & Bögen \\\\ \n"
    c << "\\hline\n"
    cc = ''
    found = false
    tutors.sort{|x,y| x.abbr_name.casecmp(y.abbr_name) }.each do |t| 
      text, anz = t.eval_against_form(form, dbh)
      next if anz.nil?
      c << "#{t.abbr_name} & #{anz} \\\\ \n"
      cc << text.to_s
      found = true
    end
    return b unless found
    c << "\\hline\n"
    c << "\\end{tabular}"
    b << c
    b << cc
    
    return b
  end
  
  def evaluate(dbh)
    eval_against_form(form.to_form, dbh)
  end
  
end

class Integer
  def to_form
    YAML::load(File.read('/home/oliver/seee/lib/forms/' + self.to_s + '.yaml'))
  end
end
