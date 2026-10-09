class AddCachedTokensAndCostSavingsToRecommendations < ActiveRecord::Migration[8.0]
  def change
    add_column :recommendations, :cached_tokens, :integer, default: 0
    add_column :recommendations, :cost_savings, :float, default: 0.0
  end
end
