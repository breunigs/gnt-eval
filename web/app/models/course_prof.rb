
class CourseProf < ActiveRecord::Base
  belongs_to :course
  belongs_to :prof
  
  include FunkyDBBits
  
  # eval and output
  def eval_against_form!(form, dbh)
    puts eval_against_form(form, dbh)
  end
  
  # evals sth against some form \o/
  # for reasons of execution speed, provide some dbi-handle!
  # returns a TeX-string
  def eval_against_form(form, dbh)

    # setup for FunkyDBBits ...
    @dbh = dbh
    @db_table = form.db_table  

    b = ''
    this_eval = ['Mathematik', 'Physik'][course.faculty] + ' ' + course.semester.title
    
    boegenanzahl = count_forms({'barcode' =>
                                 i_bcwc}) 
    
    b << "\\profkopf{#{prof.fullname}}{#{boegenanzahl}}\n\n"
    b << "\\fragenzurvorlesung\n\n"
    
    form.questions.each do |q|
      col = q.db_column
      
      # multi-q?
      if col.is_a?(Array)
        
        answers = multi_q({ 'eval' => this_eval, 'barcode' =>
                            i_bcwc}, q)

        t = TeXMultiQuestion.new(q.text, answers)
        b << t.to_tex
        
      # single-q
      else
        antw, anz, m, m_a, s, s_a = single_q({'eval' => this_eval,
                                               'barcode' =>
                                               i_bcwc},
                                             {'eval' => this_eval}, q) 
        
        t = TeXSingleQuestion.new(q.qtext, q.ltext, q.rtext, antw,
                                  anz, m, m_a, s, s_a)

        b << t.to_tex
      end
    end
    return b
  end
  
  def barcode
    return "%07d" % id
  end

  def barcode_with_checksum
    long_number = barcode.to_s
    sum = 0
    (0..6).each do |i|
      weight = 1 + 2*((i+1)%2)
      sum += weight*long_number[i,1].to_i
    end
    long_number + ((sum.to_f/10).ceil*10-sum).to_s
  end
  
  # shortform for barcode_with_checksum.to_i
  def i_bcwc
    barcode_with_checksum.to_i
  end
end
