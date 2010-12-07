class AddCourseLanguage < ActiveRecord::Migration
  def self.up
    add_column :courses, :language, :string
  end

  def self.down
    remove_column :courses, :language
  end
end
