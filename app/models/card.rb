class Card < ApplicationRecord
  belongs_to :bank

  has_many :user_cards
  has_many :users, through: :user_cards

  enum :status, { active: 0, inactive: 1 }
end
