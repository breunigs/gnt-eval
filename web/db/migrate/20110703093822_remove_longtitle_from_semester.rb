class RemoveLongtitleFromSemester < ActiveRecord::Migration
  def self.up
    remove_column :semesters, :role
  end

  def self.down
    add_column :semesters, :role, :string
  end
end
