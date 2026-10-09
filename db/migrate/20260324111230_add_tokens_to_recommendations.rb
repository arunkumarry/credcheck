class AddTokensToRecommendations < ActiveRecord::Migration[8.0]
  def change
    add_column :recommendations, :input_tokens, :integer
    add_column :recommendations, :output_tokens, :integer
  end
end
