class CreateFinancialProfiles < ActiveRecord::Migration[7.0]
  def change
    create_table :financial_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :monthly_income
      t.decimal :savings_goal
      t.string :spending_style
      t.string :financial_personality

      t.timestamps
    end
  end
end
