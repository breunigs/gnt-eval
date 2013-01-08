class AddCommentToPics < ActiveRecord::Migration
  def change
    add_column :pics, :text, :string
    add_column :pics, :step, :integer
  end
end
