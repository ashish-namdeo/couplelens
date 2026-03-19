class CreateConflictSessions < ActiveRecord::Migration[7.0]
  def change
    create_table :conflict_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :partner_name
      t.integer :status
      t.string :topic
      t.text :user_perspective
      t.text :partner_perspective
      t.text :ai_analysis
      t.text :ai_summary

      t.timestamps
    end
  end
end
