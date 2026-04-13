class AddLanguageToConflictSessions < ActiveRecord::Migration[7.0]
  def change
    add_column :conflict_sessions, :language, :string, default: 'english'
  end
end
