# encoding: utf-8

class AddRealLongtitleToSemester < ActiveRecord::Migration
  def self.up
    add_column :semesters, :longtitle, :string
  end

  def self.down
    remove_column :semesters, :longtitle
  end
end
