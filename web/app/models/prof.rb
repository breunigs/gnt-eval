# encoding: utf-8

# This means physical persons. They have many courses.
class Prof < ActiveRecord::Base
  has_many :course_profs, :inverse_of => :prof
  has_many :courses, :through => :course_profs
  validates_presence_of :firstname, :surname, :gender
  validates_uniqueness_of :email, :allow_nil => true

  strip_attributes

  def lastname
    surname
  end

  def fullname
    "#{firstname} #{surname}"
  end

  def surnamefirst
    "#{surname}, #{firstname}"
  end

  def gender
    g = read_attribute(:gender)
    g == 1 ? :male : :female
  end

  def gender_symbol
    g = read_attribute(:gender)
    g == 1 ? "♂" : "♀"
  end

  # Returns if the prof is critical. This is the case if there are any
  # associated courses
  def critical?
    course_profs.size > 0
  end
end
