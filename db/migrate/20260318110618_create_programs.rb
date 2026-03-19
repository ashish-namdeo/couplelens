class CreatePrograms < ActiveRecord::Migration[7.0]
  def change
    create_table :programs do |t|
      t.string :title
      t.text :description
      t.string :category
      t.string :difficulty
      t.integer :duration_weeks
      t.integer :status

      t.timestamps
    end
  end
end
