class RenameAgreedToPublishOk < ActiveRecord::Migration
  def up
    rename_column :profs, :agreed, :publish_ok
  end

  def down
    rename_column :profs, :publish_ok, :agreed
  end
end
