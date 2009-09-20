# -*- coding: utf-8 -*-
class Course < ActiveRecord::Base
  belongs_to :semester
  has_many :course_profs
  has_many :profs, :through => :course_profs
  has_many :tutors
  validates_presence_of :semester_id
  validates_numericality_of :students
  
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

    boegenanzahl = 0
    q = "SELECT COUNT(*) AS anzahl FROM #{form.db_table} WHERE barcode IN (?)"
    sth = dbh.prepare(q)
    sth.execute(course_profs.map{ |cp| cp.barcode_with_checksum.to_i })
    sth.fetch_hash { |r| boegenanzahl = r['anzahl'] }

    b << "\\kurskopf{#{title}}{#{profs.map { |p| p.fullname }.join(' / ')}}{#{boegenanzahl}}\n\n"
   
    # TODO: semester/abschluss
    
    b << "\\zusammenfassung\n"
    b << summary
    b << "\n\\medskip\n\n"
    
    # vorlesungseval pro dozi
    course_profs.each do |cp|
      b << cp.eval_against_form(form, dbh)
    end
    
    b << "\\fragenzudenuebungen\n"
    # TODO übungen allgemein
    
    # TODO tutor_innen
    return b
  end
  
  def eval_against_form!(form, dbh)
    puts eval_against_form(form, dbh)
  end
end
