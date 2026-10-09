class ScrapeBankOffersJob < ApplicationJob
  queue_as :default

  def perform(*args)
    GrabOnScraper::Service.call
  end
end
