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
