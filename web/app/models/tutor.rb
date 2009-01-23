class Tutor < ActiveRecord::Base
  belongs_to :course
  has_many :pics
end
