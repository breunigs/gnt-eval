class AddCriticalBoolToSemester < ActiveRecord::Migration
  def self.up
    add_column :semesters, :critical, :boolean
  end

  def self.down
    remove_column :semesters, :critical
  end
end
