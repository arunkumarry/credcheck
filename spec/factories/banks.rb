FactoryBot.define do
  factory :bank do
    sequence(:name) { |n| "Bank #{n}" }
  end
end
