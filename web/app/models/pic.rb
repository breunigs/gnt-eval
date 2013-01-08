# encoding: utf-8

class Pic < ActiveRecord::Base
  belongs_to :tutor, :inverse_of => :pics
  has_one :course, :through => :tutor
  has_one :term, :through => :tutor

  validates :step, :numericality => { :only_integer => true }

  def for
    "tutor " + tutor.abbr_name
  end
end
