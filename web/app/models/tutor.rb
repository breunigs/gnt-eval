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

    b = ''
    if boegenanzahl > 2
      #b << "\\profkopf{#{prof.fullname}}{#{boegenanzahl}}\n\n"
      #b << "\\fragenzurvorlesung\n\n"
      
#      form.questions.find_all{ |q| q.section == 'tutor' }.each do |q|
#        b << q.eval_to_tex(this_eval, barcode.to_i, form.db_table, @dbh)
#      end
    end
    return b
  end
  
  def tutnum
    course.tutors.sort{ |x,y| x.id <=> y.id }.index(self) + 1
  end
end
