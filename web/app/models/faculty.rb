# encoding: utf-8

class Faculty < ActiveRecord::Base
  has_many :courses, :inverse_of => :faculty
  has_many :course_profs, :through => :courses
  validates_presence_of :shortname, :longname
  validates_uniqueness_of :shortname, :longname

  # returns true if there are any courses associated with this faculty
  def critical?
    courses.size > 0
  end

  # returns array of integer-barcodes for all associated CourseProfs
  def barcodes
    course_profs.map { |cp| cp.id }
  end
end
