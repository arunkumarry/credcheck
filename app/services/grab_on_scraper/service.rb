require "nokogiri"
require "open-uri"

module GrabOnScraper
  class Service
    BASE_URL = "https://www.grabon.in"
    BANK_OFFERS_URL = "#{BASE_URL}/bank-offers/"

    def self.call
      new.call
    end

    def call
      bank_pages = fetch_bank_pages
      puts "Found #{bank_pages.count} bank pages."

      bank_pages.each do |bank_name, path|
        scrape_bank_page(bank_name, path)
      end
    end

    private

    def fetch_bank_pages
      doc = fetch_doc(BANK_OFFERS_URL)
      return {} unless doc

      pages = {}
      doc.css("a").each do |link|
        href = link.attr("href")
        next unless href&.include?("-card-offers") || href&.include?("-offers")

        bank_name = link.text.strip.split("\n").first
        pages[bank_name] = href.start_with?("http") ? href : "#{BASE_URL}#{href}"
      end
      pages
    end

    def scrape_bank_page(bank_name, url)
      puts "Scraping #{bank_name} at #{url}..."
      doc = fetch_doc(url)
      return unless doc

      # Try to find the bank in our DB
      bank = Bank.find_by("name ILIKE ?", "%#{bank_name.gsub(' Card', '')}%")

      # Fallback to searching for text patterns if .gc-box is not found
      containers = doc.css(".gc-box")
      if containers.empty?
        # Find elements that contain keywords like "OFF", "Cashback", "Discount"
        containers = doc.css("div, li").select { |el| el.text.match?(/OFF|Cashback|Discount|Rs\s?\d+/) && el.text.length < 1000 }
      end

      containers.each do |card|
        title = card.css("h3, .title, b").first&.text&.strip
        title ||= card.text.split("\n").first&.strip if card.text.include?("OFF")

        details = card.text.strip.gsub(/\s+/, " ")

        merchant_link = card.css("a").find { |a| a.text.include?("View All") || a.text.include?("Offers") }
        merchant_name = merchant_link&.text&.gsub(/View All | Offers/, "")&.strip

        next if title.blank? || title.length > 200

        save_offer(bank, merchant_name, title, details, url)
      end
    end

    def save_offer(bank, merchant, title, details, url)
      offer = BankOffer.find_or_initialize_by(
        bank: bank,
        merchant_name: merchant,
        offer_details: "#{title}\n#{details}"
      )

      offer.source_url = url
      offer.category = infer_category(title, details)

      if offer.save
        puts "Saved offer: #{title} for #{merchant}"
      end
    end

    def infer_category(title, details)
      text = "#{title} #{details}".downcase
      return "Travel" if text.match?(/flight|hotel|bus|travel|stay/)
      return "Dining" if text.match?(/food|dining|zomato|swiggy|restaurant/)
      return "Groceries" if text.match?(/grocery|bigbasket|blinkit|zepto/)
      return "Electronics" if text.match?(/laptop|mobile|tv|appliance|samsung|apple/)
      return "Shopping" if text.match?(/amazon|flipkart|ajio|myntra|fashion|clothing/)
      "Other"
    end

    def fetch_doc(url)
      headers = {
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
        "Accept-Language" => "en-US,en;q=0.9",
        "Referer" => "https://www.google.com/"
      }

      html = URI.open(url, headers).read
      Nokogiri::HTML(html)
    rescue => e
      Rails.logger.error "GrabOn Scraper failed for #{url}: #{e.message}"
      nil
    end
  end
end
