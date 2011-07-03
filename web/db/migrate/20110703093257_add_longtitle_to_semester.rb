class AddLongtitleToSemester < ActiveRecord::Migration
  def self.up
    add_column :semesters, :role, :string
  end

  def self.down
    remove_column :semesters, :role
  end
end
