class AddSubscriptionToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :subscription_plan, :string
  end
end
