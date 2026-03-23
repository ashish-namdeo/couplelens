class AddMessagingPlatformFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :telegram_id, :string
    add_column :users, :whatsapp_id, :string
    add_index :users, :telegram_id, unique: true, where: "telegram_id IS NOT NULL"
    add_index :users, :whatsapp_id, unique: true, where: "whatsapp_id IS NOT NULL"
  end
end
