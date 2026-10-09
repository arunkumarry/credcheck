class AddApiTokenToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :api_token, :string
    add_index :users, :api_token, unique: true

    reversible do |dir|
      dir.up do
        User.reset_column_information
        User.find_each do |user|
          user.regenerate_api_token if user.respond_to?(:regenerate_api_token)
        end
      end
    end
  end
end
