class FacultyLongAndShortname < ActiveRecord::Migration
  def self.up
    rename_column :faculties, :name, :longname
    add_column :faculties, :shortname, :string
  end

  def self.down
    remove_column :faculties, :shortname
    rename_column :faculties, :longname, :name
  end
end
