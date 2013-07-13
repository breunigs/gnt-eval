class AddCensorToTutors < ActiveRecord::Migration
  def change
    add_column :tutors, :censor, :string
  end
end
