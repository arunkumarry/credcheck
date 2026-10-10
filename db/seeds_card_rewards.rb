# Reward structures for known cards, stored on Card#data["reward_summary"].
# This is the platform's own card-discount knowledge that the agent folds into
# every recommendation (base rewards), on top of any LIVE offer it finds.
# Re-runnable: updates existing cards in place.

CARD_REWARDS = {
  "Amazon Pay ICICI" => "5% cashback on Amazon.in for Prime members (3% for non-Prime), 2% on 100+ Amazon Pay partner merchants, and 1% on all other spends. Uncapped, credited as Amazon Pay balance.",
  "Regalia Gold"     => "4 Reward Points per Rs.150 spent (about 1.3% base value; up to ~2.6% on flights/hotels via SmartBuy). 5X Reward Points on Myntra, Nykaa, Marks & Spencer and Reliance Digital.",
  "Infinia"          => "5 Reward Points per Rs.150 (about 3.3% base value, up to 5X on SmartBuy). Among the most rewarding premium cards.",
  "Millennia"        => "5% cashback on Amazon, Flipkart, Myntra, Swiggy, Zomato, Uber and more; 1% on all other spends (capped monthly).",
  "Axis Ace"         => "5% cashback on bill payments, recharges and DTH via Google Pay; 4% on Swiggy, Zomato and Ola; 1.5% unlimited cashback on all other spends.",
  "Magnus"           => "12 EDGE Reward Points per Rs.200 (about 2% base); up to 35 points per Rs.200 on travel via EDGE; strong on high-value spends.",
  "Flipkart Axis"    => "5% cashback on Flipkart, Myntra and Cleartrip; 4% on preferred partners (Swiggy, PVR, Uber, cleartrip); 1.5% on all other spends.",
  "SBI Cashback"     => "5% cashback on all online spends (no merchant restriction), 1% on offline spends. Capped monthly.",
  "SimplyCLICK"      => "10X Reward Points on Amazon, BookMyShow, Cleartrip and more; 5X on other online spends; 1 point per Rs.100 otherwise.",
  "Coral"            => "2 Reward Points per Rs.100 (about 0.5% base); 4X on retail and dining; movie ticket discounts.",
  "Sapphiro"         => "4 Reward Points per Rs.100 (about 1% base); 6X on international and premium spends; travel benefits.",
  "HSBC Cashback"    => "1.5% unlimited cashback on all online spends, 1% on all other spends. No cap.",
  "HSBC Platinum"    => "2 Reward Points per Rs.100 (about 0.5% base); 5X accelerated points on select categories."
}

updated = 0
CARD_REWARDS.each do |name, summary|
  Card.where(name: name).find_each do |card|
    data = card.data || {}
    data["reward_summary"] = summary
    card.update_columns(data: data)
    updated += 1
  end
end
puts "Seeded reward structures for #{updated} card record(s)."
