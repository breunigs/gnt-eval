# encoding: utf-8

class CPic < ActiveRecord::Base
  belongs_to :course_prof
  has_one :semester, :through => :course_prof
end
