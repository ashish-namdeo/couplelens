class CreateWorkshops < ActiveRecord::Migration[7.0]
  def change
    create_table :workshops do |t|
      t.string :title
      t.text :description
      t.string :instructor
      t.string :location
      t.datetime :workshop_date
      t.decimal :price
      t.integer :capacity
      t.integer :spots_taken
      t.integer :status
      t.string :workshop_type

      t.timestamps
    end
  end
end
