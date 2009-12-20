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
<<<<<<< HEAD:web/app/models/tutor.rb
      b << "\\section{#{abbr_name}}\n\n"
=======
      #gender = prof.gender == 1 ? "M" : "F"
      #b << "\\profkopf#{gender}{#{prof.fullname}}{#{boegenanzahl}}\n\n"
      #b << "\\fragenzurvorlesung\n\n"
>>>>>>> 2b5eed0e3f9f1a0a7febbcb7196866e414853d5d:web/app/models/tutor.rb
      
      specific = { :barcode => course.course_profs.map{ |cp| cp.barcode.to_i}, :tutnum => tutnum }
      general = { :barcode => course.course_profs.map{ |cp| cp.barcode.to_i }}
      form.questions.find_all{ |q| q.section == 'tutor' }.each do |q|
        b << q.eval_to_tex(specific, general, form.db_table, @dbh)
      end
      if not comment.to_s.empty?
        b << "\\paragraph{Kommentare}"
        b << comment.to_s
      end
    end
    return b
  end
  
  def tutnum
    course.tutors.sort{ |x,y| x.id <=> y.id }.index(self) + 1
  end
end
