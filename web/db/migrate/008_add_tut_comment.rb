# encoding: utf-8

class AddTutComment < ActiveRecord::Migration
  def self.up
    add_column :tutors, :comment, :text
  end

  def self.down
    remove_column :tutors, :comment
  end
end
