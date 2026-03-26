class AddPlatformToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :platform, :string, default: 'web'
    add_index :conversations, :platform
  end
end
