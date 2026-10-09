class CardScraperJob < ApplicationJob
  queue_as :card_scraper

  def perform
    cards = Card.active
    cards.each do |card|
      begin
        if card.last_scraped_at.present? && card.last_scraped_at > 1.day.ago
          next
        end
        scraper = Scraper.new(card)
        scraper.call
        card.update!(last_scraped_at: Time.now)
      rescue StandardError => e
        Rails.logger.warn(e.message)
      end
    end
  end
end
