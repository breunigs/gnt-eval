class FacultyFix < ActiveRecord::Migration
  def self.up
    rename_column :courses, :faculty, :faculty_id
  end

  def self.down
    rename_column :courses, :faculty_id, :faculty
  end
end
