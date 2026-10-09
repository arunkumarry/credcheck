require 'rails_helper'

RSpec.describe Scraper do
  describe "#call" do
    before do
			@card  = create(:card)
    end

    it "returns false if card is nil" do
			scraper = Scraper.new(nil)
			expect(scraper.call).to be_falsey
    end

		it "returns true if card is valid" do
			scraper = Scraper.new(@card)
			allow(scraper).to receive(:extract_and_save).and_return(true)
			expect(scraper.call).to be_truthy
		end
  end
end
