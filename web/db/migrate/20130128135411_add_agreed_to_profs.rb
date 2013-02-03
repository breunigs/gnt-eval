class AddAgreedToProfs < ActiveRecord::Migration
  def change
    add_column :profs, :agreed, :boolean, :default => false
  end
end
