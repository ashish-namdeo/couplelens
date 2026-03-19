class CreateCompatibilityAssessments < ActiveRecord::Migration[7.0]
  def change
    create_table :compatibility_assessments do |t|
      t.references :user, null: false, foreign_key: true
      t.string :partner_name
      t.float :financial_score
      t.float :lifestyle_score
      t.float :parenting_score
      t.float :overall_score
      t.text :strengths
      t.text :risk_areas
      t.text :full_report
      t.integer :status

      t.timestamps
    end
  end
end
