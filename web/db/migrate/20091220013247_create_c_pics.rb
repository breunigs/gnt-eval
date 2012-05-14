# encoding: utf-8

class CreateCPics < ActiveRecord::Migration
  def self.up
    create_table :c_pics do |t|
      t.string :basename
      t.references :course

      t.timestamps
    end
  end

  def self.down
    drop_table :c_pics
  end
end
