class AddMailsSentToCourses < ActiveRecord::Migration
  def change
    add_column :courses, :mails_sent, :string
  end
end
