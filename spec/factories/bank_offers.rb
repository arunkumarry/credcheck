FactoryBot.define do
  factory :bank_offer do
    bank { nil }
    merchant_name { "MyString" }
    offer_details { "MyText" }
    category { "MyString" }
    expiry_date { "2026-05-02" }
    source_url { "MyString" }
  end
end
