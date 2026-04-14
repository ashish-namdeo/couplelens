class AddSlugToConversationsConflictSessionsCompatibilityAssessments < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :slug, :string
    add_column :conflict_sessions, :slug, :string
    add_column :compatibility_assessments, :slug, :string

    add_index :conversations, :slug, unique: true
    add_index :conflict_sessions, :slug, unique: true
    add_index :compatibility_assessments, :slug, unique: true
  end
end
