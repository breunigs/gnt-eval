class Faculty < ActiveRecord::Base
  has_many :courses
  validates_presence_of :shortname, :longname

  # returns true if there are any courses associated with this faculty
  def critical?
    courses.size > 0
  end
end
