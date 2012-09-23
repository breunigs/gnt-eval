# encoding: utf-8

class AddFormIdToCourses < ActiveRecord::Migration
  def self.up
    add_column :courses, :form_id, :integer
  end

  def self.down
    remove_column :courses, :form_id
  end
end
