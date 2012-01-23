class Pic < ActiveRecord::Base
  belongs_to :tutor
  has_one :semester, :through => :tutor
end
