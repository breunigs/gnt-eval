class Courseprofpics < ActiveRecord::Migration
  def self.up
     rename_column :c_pics, :course_id, :course_prof_id
  end

  def self.down
     rename_column :c_pics, :course_prof_id, :course_id
  end
end
