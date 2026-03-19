class CreateConversations < ActiveRecord::Migration[7.0]
  def change
    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.string :persona
      t.integer :status

      t.timestamps
    end
  end
end
