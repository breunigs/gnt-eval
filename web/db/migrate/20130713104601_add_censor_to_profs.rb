class AddCensorToProfs < ActiveRecord::Migration
  def change
    add_column :profs, :censor, :string
  end
end
