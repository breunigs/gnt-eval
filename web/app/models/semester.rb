class Semester < ActiveRecord::Base
  has_many :courses
  validates_presence_of :title
end
