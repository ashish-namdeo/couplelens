class AddBotLinkCodeToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :bot_link_code, :string
    add_column :users, :bot_link_code_expires_at, :datetime
  end
end
