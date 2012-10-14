# encoding: utf-8

class Pic < ActiveRecord::Base
  belongs_to :tutor, :inverse_of => :pics
  has_one :term, :through => :tutor
end
