class CreateSessions < ActiveRecord::Migration
  def change
    create_table :sessions do |t|
      t.string :ident
      t.string :cont
      t.integer :viewed_id

      t.timestamps
    end
  end
end
