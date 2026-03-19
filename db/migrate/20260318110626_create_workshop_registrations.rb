class CreateWorkshopRegistrations < ActiveRecord::Migration[7.0]
  def change
    create_table :workshop_registrations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :workshop, null: false, foreign_key: true
      t.integer :status
      t.decimal :amount_paid

      t.timestamps
    end
  end
end
