class CreateBookings < ActiveRecord::Migration[7.0]
  def change
    create_table :bookings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :therapist_profile, null: false, foreign_key: true
      t.string :session_type
      t.datetime :scheduled_at
      t.integer :duration
      t.integer :status
      t.text :notes
      t.decimal :amount

      t.timestamps
    end
  end
end
