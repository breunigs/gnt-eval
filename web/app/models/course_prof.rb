class CourseProf < ActiveRecord::Base
  belongs_to :course
  belongs_to :prof
  
  # evals sth against some form \o/
  # for reasons of execution speed, provide some dbi-handle!
  def eval_against_form(form, dbh)
    
  end
  
  def barcode
    return "%07d" % id
  end
end
