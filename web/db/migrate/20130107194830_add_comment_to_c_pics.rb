class AddCommentToCPics < ActiveRecord::Migration
  def change
    add_column :c_pics, :text, :string
    add_column :c_pics, :step, :integer
  end
end
