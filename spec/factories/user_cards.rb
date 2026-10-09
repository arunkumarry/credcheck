FactoryBot.define do
  factory :user_card do
    association :user
    association :card
    status { :active }
  end
end
