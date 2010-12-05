class FormIToOldFormI < ActiveRecord::Migration
  def self.up
    rename_column :courses, :form, :old_form_i
  end

  def self.down
    rename_column :courses, :old_form_i, :form
  end
end
