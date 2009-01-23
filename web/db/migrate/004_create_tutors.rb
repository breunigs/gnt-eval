class CreateTutors < ActiveRecord::Migration
  def self.up
    create_table :tutors do |t|
      t.references :course
      t.string :abbr_name

      t.timestamps
    end
  end

  def self.down
    drop_table :tutors
  end
end
