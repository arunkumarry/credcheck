require 'nokogiri'
require 'open-uri'

url = "https://www.grabon.in/sbi-card-offers/"
html = URI.open(url, "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36").read
doc = Nokogiri::HTML(html)

puts "Finding offer containers..."
puts "Analyzing all classes on page..."
classes = []
doc.css('*').each { |el| classes << el.attr('class') if el.attr('class') }
puts classes.uniq.grep(/coupon|offer|card/).first(50)

doc.css('.gc-box').each do |card|
  title = card.css('h3').text.strip
  desc = card.css('.gc-box-rt p').text.strip # Often p tags contain the details
  merchant = card.css('.gc-box-lt img').attr('alt').to_s.gsub(' Coupons', '')
  
  next if title.empty?

  puts "Merchant: #{merchant}"
  puts "Title: #{title}"
  puts "Details: #{desc}"
  puts "-" * 20
end
