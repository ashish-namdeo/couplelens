class CreateTherapistApplications < ActiveRecord::Migration[7.0]
  def change
    create_table :therapist_applications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :full_name
      t.string :email
      t.string :specialization
      t.text :bio
      t.text :certifications
      t.integer :years_experience
      t.decimal :hourly_rate
      t.integer :status
      t.text :admin_notes

      t.timestamps
    end
  end
end
