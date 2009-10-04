class Tutor < ActiveRecord::Base
  belongs_to :course
  has_many :pics
  
  def eval_against_form(form, dbh)
  end
end
