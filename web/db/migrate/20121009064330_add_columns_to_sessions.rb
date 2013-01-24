class AddColumnsToSessions < ActiveRecord::Migration
  def change
    add_column :sessions, :ip, :string
    add_column :sessions, :agent, :string
    add_column :sessions, :username, :string
  end
end
