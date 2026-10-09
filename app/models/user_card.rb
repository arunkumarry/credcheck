class UserCard < ApplicationRecord
  self.table_name = "users_cards"

  belongs_to :user
  belongs_to :card

  enum :status, { active: 0, inactive: 1 }
end