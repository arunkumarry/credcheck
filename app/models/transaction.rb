class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :recommendation
  belongs_to :card, optional: true

  def recommended_card_name
    return nil unless recommendation&.data.is_a?(Array)

    recommended_entry = recommendation.data.find { |r| r["recommended"].to_s == "true" }
    recommended_entry&.[]("card_name")
  end
end
