# This means physical persons. They have many courses.
class Prof < ActiveRecord::Base
  has_many :course_profs
  has_many :courses, :through => :course_profs
  validates_presence_of :firstname, :surname, :gender
  def fullname
    return firstname.strip + ' ' + surname.strip
  end
  def surnamefirst
    return surname.strip + ', ' + firstname.strip
  end
end
