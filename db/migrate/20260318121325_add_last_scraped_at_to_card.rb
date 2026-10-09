class AddLastScrapedAtToCard < ActiveRecord::Migration[8.0]
  def change
    add_column :cards, :last_scraped_at, :datetime
  end
end
