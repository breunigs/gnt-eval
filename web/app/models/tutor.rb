# tutors belong to a course.
class Tutor < ActiveRecord::Base
  belongs_to :course
  has_many :pics
  include FunkyDBBits
  include FunkyTeXBits
  
  def eval_against_form(form, dbh)
    @dbh = dbh
    @db_table = form.db_table
    boegenanzahl = count_forms({:barcode => course.course_profs.map{ |cp| cp.barcode.to_i},
                                :tutnum => tutnum}) 


    return '', nil unless boegenanzahl > 2
    b = "\\section{#{abbr_name}}\n\\label{#{id}}\n"
    b << "#{form.getSheetCount}: #{boegenanzahl}\n\n"
    
    specific = { :barcode => course.course_profs.map{ |cp| cp.barcode.to_i}, :tutnum => tutnum }
    general = { :barcode => course.course_profs.map{ |cp| cp.barcode.to_i }}
    form.questions.find_all{ |q| q.section == 'tutor' }.each do |q|
      b << q.eval_to_tex(specific, general, form.db_table, @dbh)
    end
    if not comment.to_s.empty?
      if form.isEnglish?
        b << "\\paragraph{Comments}"
      else
        b << "\\paragraph{Kommentare}"
      end
      b << comment.to_s
    end
    return b, boegenanzahl
  end
  
  def tutnum
    course.tutors.sort{ |x,y| x.id <=> y.id }.index(self) + 1
  end
end
