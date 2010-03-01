# tutors belong to a course.
class Tutor < ActiveRecord::Base
  belongs_to :course
  has_many :pics
  include FunkyDBBits
  include FunkyTeXBits
  
  def eval_against_form(form, dbh)
    @dbh = dbh
    @db_table = form.db_table

    return '', nil unless boegenanzahl(@dbh) > 2
    b = ''
    b << "\\section{#{abbr_name}}\n\n"
    
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
  
  def competence(dbh)
    @dbh = dbh
    @db_table = course.form.to_form.db_table
    competence_field = 'AVG(t2)'
    query(competence_field, { :barcode => course.course_profs.map{ |cp| cp.barcode.to_i}, :tutnum => tutnum}, " AND t2 > 0").to_f
  end
  
  def profit(dbh)
    @dbh = dbh
    @db_table = course.form.to_form.db_table
    profit_field = 'AVG(t10)'
    query(profit_field, { :barcode => course.course_profs.map{ |cp| cp.barcode.to_i}, :tutnum => tutnum}, " AND t10 > 0").to_f
    
  end
  
  def teacher(dbh)
    @dbh = dbh
    @db_table = course.form.to_form.db_table
    teacher_field = 'AVG(t1)'
    query(teacher_field, { :barcode => course.course_profs.map{ |cp| cp.barcode.to_i}, :tutnum => tutnum}, " AND t1 > 0").to_f
    
  end
  def preparation(dbh)
    @dbh = dbh
    @db_table = course.form.to_form.db_table
    prep_field = 'AVG(t3)'
    query(prep_field, { :barcode => course.course_profs.map{ |cp| cp.barcode.to_i}, :tutnum => tutnum}, " AND t3 > 0").to_f
    
  end
  def boegenanzahl(dbh)
    @dbh = dbh
    @db_table = course.form.to_form.db_table
    count_forms({:barcode => course.course_profs.map{ |cp| cp.barcode.to_i},
                                :tutnum => tutnum}) 
  end
end
