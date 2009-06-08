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
end
