class AddSummary < ActiveRecord::Migration
  def self.up
    add_column :courses, :summary, :text
  end

  def self.down
    remove_column :courses, :summary
  end
end
