# encoding: utf-8

class CreateProfs < ActiveRecord::Migration
  def self.up
    create_table :profs do |t|
      t.string :firstname
      t.string :surname
      t.string :email
      t.integer :gender

      t.timestamps
    end
  end

  def self.down
    drop_table :profs
  end
end
