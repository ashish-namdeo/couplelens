class AddOtpFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :otp_code, :string
    add_column :users, :otp_sent_at, :datetime
    add_column :users, :otp_verified, :boolean
  end
end
