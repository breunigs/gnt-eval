# encoding: utf-8

class CreateCourses < ActiveRecord::Migration
  def self.up
    create_table :courses do |t|
      t.references :semester
      t.string :title
      t.integer :students
      t.integer :faculty
      t.integer :form
      t.string :evaluator
      t.string :description

      t.timestamps
    end
  end

  def self.down
    drop_table :courses
  end
end
