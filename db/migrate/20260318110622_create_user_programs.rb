class CreateUserPrograms < ActiveRecord::Migration[7.0]
  def change
    create_table :user_programs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :program, null: false, foreign_key: true
      t.integer :current_lesson
      t.integer :status
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
