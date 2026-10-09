class Recommendation < ApplicationRecord
  belongs_to :user, optional: true
  has_many :transactions
  after_commit :create_transaction, on: :create

  private

  def create_transaction
    user = Current.user
    unless user
      Rails.logger.warn("create_transaction skipped: no current user")
      return
    end

    best_card_data = self.data.is_a?(Array) ? (self.data.find { |r| r["recommended"].to_s == "true" } || self.data.first) : {}
    best_card_data ||= {}

    rewards_val = best_card_data["reward_amount"] || extract_amount(best_card_data["rewards"])
    coupon_val = best_card_data["coupon_savings_amount"] || extract_amount(best_card_data["coupon_savings"])
    total_savings = rewards_val.to_f + coupon_val.to_f

    card_name = best_card_data["card_name"].to_s.downcase
    card = user.cards.find { |c| c.name.downcase == card_name } if card_name.present?

    Transaction.create!(
      user:,
      recommendation: self,
      category: self.category,
      amount: self.amount,
      saved_amount: total_savings,
      card: card
    )
  rescue => e
    Rails.logger.error("create_transaction failed for Recommendation##{id}: #{e.message}")
  end

  def extract_amount(value)
    return 0.0 if value.blank? || value.to_s.downcase == "null"

    # Try to find the first numeric sequence (handles commas and decimals)
    # This prevents concatenating multiple numbers (like 1% and 9000)
    match = value.to_s.gsub(",", "").match(/\d+(\.\d+)?/)
    match ? match[0].to_f : 0.0
  end
end
