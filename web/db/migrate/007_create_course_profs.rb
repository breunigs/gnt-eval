class CreateCourseProfs < ActiveRecord::Migration
  def self.up
    create_table :course_profs do |t|
      t.references :course
      t.references :prof
    end
  end

  def self.down
    drop_table :course_profs
  end
end
