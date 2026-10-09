FactoryBot.define do
  factory :card do
    sequence(:name) { |n| "Card #{n}" }
    status { :active }
    association :bank
  end
end
