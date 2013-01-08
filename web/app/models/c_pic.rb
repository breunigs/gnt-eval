# encoding: utf-8

class CPic < ActiveRecord::Base
  belongs_to :course_prof, :inverse_of => :c_pics
  has_one :course, :through => :course_prof
  has_one :term, :through => :course_prof

  validates :step, :numericality => { :only_integer => true }

  def for
    "prof " + course_prof.prof.fullname
  end
end
