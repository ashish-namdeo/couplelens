class CreateMemories < ActiveRecord::Migration[7.0]
  def change
    create_table :memories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.date :memory_date
      t.string :memory_type

      t.timestamps
    end
  end
end
