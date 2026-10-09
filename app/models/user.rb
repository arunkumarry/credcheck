class User < ApplicationRecord
  has_secure_password
  has_secure_token :api_token
  has_many :sessions, dependent: :destroy
  has_many :transactions

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :first_name, presence: true
  validates :last_name, presence: true
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  enum :status, { active: 0, inactive: 1 }
  has_many :user_cards
  has_many :cards, through: :user_cards
  has_many :recommendations

  def free_tier?
    subscription_plan.blank? || subscription_plan == "free"
  end

  def active_cards_limit
    free_tier? ? 3 : Float::INFINITY
  end

  def weekly_recommendations_limit
    free_tier? ? 10 : Float::INFINITY
  end

  def recommendations_this_week
    recommendations.where("created_at >= ?", 1.week.ago).count
  end

  def can_add_card?
    user_cards.active.count < active_cards_limit
  end

  def can_get_recommendation?
    recommendations_this_week < weekly_recommendations_limit
  end
end
