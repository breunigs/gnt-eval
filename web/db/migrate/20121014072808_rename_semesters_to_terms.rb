class RenameSemestersToTerms < ActiveRecord::Migration
  def change
    rename_table :semesters, :terms
    rename_column :courses, :semester_id, :term_id
    rename_column :forms, :semester_id, :term_id
  end
end
