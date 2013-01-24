class AddCommentToCPics < ActiveRecord::Migration
  def change
    add_column :c_pics, :text, :text
    add_column :c_pics, :step, :integer
  end
end
