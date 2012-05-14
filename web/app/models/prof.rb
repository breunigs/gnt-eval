# encoding: utf-8

# This means physical persons. They have many courses.
class Prof < ActiveRecord::Base
  has_many :course_profs
  has_many :courses, :through => :course_profs
  validates_presence_of :firstname, :surname, :gender
  validates_uniqueness_of :email, :allow_nil => true

  def lastname
    surname
  end

  def fullname
    "#{firstname} #{surname}".gsub(/\s+/, " ")
  end

  def surnamefirst
    "#{surname} #{firstname}".gsub(/\s+/, " ")
  end

  def gender
    g = read_attribute(:gender)
    if g == 1
      return :male
    else
      return :female
    end
  end

  # Returns if the prof is critical. This is the case if there are any
  # associated courses
  def critical?
    course_profs.size > 0
  end
end
