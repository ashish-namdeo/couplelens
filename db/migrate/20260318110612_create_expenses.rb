class CreateExpenses < ActiveRecord::Migration[7.0]
  def change
    create_table :expenses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :category
      t.decimal :amount
      t.string :description
      t.date :expense_date
      t.boolean :shared

      t.timestamps
    end
  end
end
