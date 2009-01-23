class AddContactInformation < ActiveRecord::Migration
  def self.up
    add_column :courses, :fscontact, :string
  end

  def self.down
    remove_column :courses, :fscontact
  end
end
