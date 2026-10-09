FactoryBot.define do
  factory :user do
    first_name { "Jane" }
    last_name  { "Doe" }
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password              { "password123" }
    password_confirmation { "password123" }
    status { :active }
  end
end
