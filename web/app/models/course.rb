# -*- coding: utf-8 -*-

# A course has many professors, belongs to a semester and has a lot of
# tutors. The semantic could be a lecute, some seminar, tutorial etc.
class Course < ActiveRecord::Base
  belongs_to :semester
  has_many :course_profs
  has_many :profs, :through => :course_profs
  has_many :tutors
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
    if boegenanzahl > 0
      b << "\\kurskopf{#{title}}{#{profs.map { |p| p.fullname }.join(' / ')}}{#{boegenanzahl}}\n\n"
      
      # TODO: semester/abschluss
      
      b << "\\zusammenfassung\n"
      b << summary.to_s
      b << "\n\\medskip\n\n"
      
      # vorlesungseval pro dozi
      course_profs.each do |cp|
        b << cp.eval_against_form(form, dbh).to_s
      end
      
      # uebungen allgemein
      b << "\\fragenzudenuebungen\n"
      form.questions.find_all{ |q| q.section == 'uebungsgruppenbetrieb'}.each do |q|
        b << q.eval_to_tex(this_eval, course_profs.map { |cp| cp.barcode.to_i
                           }, form.db_table, @dbh).to_s
      end

      # TODO tutor_innen
      tutors.each do |t|
        b << t.eval_against_form(form, dbh).to_s
      end
    end
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
