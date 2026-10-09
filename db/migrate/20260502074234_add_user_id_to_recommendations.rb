class AddUserIdToRecommendations < ActiveRecord::Migration[8.0]
  def change
    add_reference :recommendations, :user, null: true, foreign_key: true
  end
end
