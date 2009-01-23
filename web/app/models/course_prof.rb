class CourseProf < ActiveRecord::Base
  belongs_to :course
  belongs_to :prof
end
