banks = [
  { name: "HDFC Bank", description: "HDFC Bank Limited" },
  { name: "ICICI Bank", description: "ICICI Bank Limited" },
  { name: "State Bank of India", description: "State Bank of India (SBI)" },
  { name: "Axis Bank", description: "Axis Bank Limited" },
  { name: "HSBC Bank", description: "HSBC India" }
]

banks.each do |bank_attrs|
  Bank.find_or_create_by!(name: bank_attrs[:name]) do |b|
    b.description = bank_attrs[:description]
  end
end

puts "Seeded #{Bank.count} banks."

# --- Demo cards (so the recommender has a catalogue to pick from) ---
demo_cards = {
  "HDFC Bank"  => [ "Regalia Gold", "Millennia", "Infinia" ],
  "ICICI Bank" => [ "Amazon Pay ICICI", "Coral", "Sapphiro" ],
  "Axis Bank"  => [ "Axis Ace", "Magnus", "Flipkart Axis" ],
  "State Bank of India" => [ "SBI Cashback", "SimplyCLICK" ],
  "HSBC Bank"  => [ "HSBC Cashback", "HSBC Platinum" ]
}

demo_cards.each do |bank_name, card_names|
  bank = Bank.find_by(name: bank_name)
  next unless bank

  card_names.each do |card_name|
    Card.find_or_create_by!(name: card_name, bank: bank) { |c| c.status = :active }
  end
end
puts "Seeded #{Card.count} cards."

# --- Demo user with a 3-card wallet, for trying the live recommendation flow ---
demo = User.find_or_initialize_by(email_address: "demo@credcheck.in")
if demo.new_record?
  demo.assign_attributes(
    first_name: "Demo",
    last_name: "User",
    password: "password123",
    password_confirmation: "password123"
  )
  demo.save!
  puts "Created demo user demo@credcheck.in / password123"
else
  puts "Demo user already exists (demo@credcheck.in)"
end

wallet = [
  [ "ICICI Bank", "Amazon Pay ICICI" ],
  [ "HDFC Bank",  "Regalia Gold" ],
  [ "Axis Bank",  "Axis Ace" ]
]
wallet.each do |bank_name, card_name|
  bank = Bank.find_by(name: bank_name)
  card = Card.find_by(name: card_name, bank: bank)
  next unless card

  UserCard.find_or_create_by!(user: demo, card: card) { |uc| uc.status = :active }
end
puts "Demo wallet: #{demo.user_cards.active.count} active cards."
