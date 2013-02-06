class AddUnencryptedOkToProfs < ActiveRecord::Migration
  def change
    add_column :profs, :unencrypted_ok, :boolean
  end
end
