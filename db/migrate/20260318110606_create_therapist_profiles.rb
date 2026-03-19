class CreateTherapistProfiles < ActiveRecord::Migration[7.0]
  def change
    create_table :therapist_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :specialization
      t.text :bio
      t.decimal :hourly_rate
      t.string :languages
      t.text :certifications
      t.integer :years_experience
      t.integer :status
      t.float :rating

      t.timestamps
    end
  end
end
