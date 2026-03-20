class AddLanguageToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :language, :string
  end
end
