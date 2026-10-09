class Scraper
  attr_reader :card

  SERP_API_URI = "https://serpapi.com/search"
  TMP_DIR = Rails.root.join("tmp", "google_files")

  def initialize(card)
    @card = card
    @api_key = ENV["SERP_API_KEY"]
    @embedder = Embedding::Embedding.new
  end

  def call
    return false if invalid?
    extract_and_save
  end

  private

  def invalid?
    card.nil?
  end

  def extract_and_save
    # Delete old embeddings for this card to prevent duplicates and keep RAG accurate
    Document.where("title LIKE ?", "#{card.name}_%").destroy_all
    fetch_documents
  end

  def fetch_documents
    query = "#{card.bank.name} #{card.name} reward points structure"
    serp_url = SERP_API_URI
    res = HTTParty.get(
      serp_url,
      query: {
        engine: "google",
        q: query,
        api_key: ENV["SERP_API_KEY"],
      },
      headers: {
        "User-Agent" => "Mozilla/5.0"
      },
      timeout: 30
    )

    return [] unless res.success?

    organic_results = res["organic_results"] || []
    organic_results.first(3).each do |result|
      link_extract_and_embed(result["link"]) if result["link"].present?
    end
  end

  def link_extract_and_embed(link)
    page = fetch_full_page(link)
    full_text = extract_full_text(page)
    unless full_text.blank?
      puts "Starting embedding extracted text: #{full_text.truncate(25)}"
      begin
        vector = @embedder.embed_text(full_text)
        title = card.name + "_#{Time.now.to_i}"
        Embedding::VectorStore.add(title, full_text, vector)
        true
      rescue StandardError => e
        Rails.logger.warn(e.message)
        false
      end
    end
  end

  def fetch_full_page(url)
    res = HTTParty.get(url, headers: {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
    })

    return nil unless res.success?

    Nokogiri::HTML(res.body)
  end

  def extract_full_text(noko_content)
    # Remove tags that contain noise: scripts, CSS, navigation, headers/footers
    noko_content.css("script, style, nav, header, footer, iframe, noscript").each(&:remove)

    # Extract only meaningful text from the body
    text = noko_content.xpath("//body//text()")
                       .map(&:text)
                       .map(&:strip)
                       .reject(&:empty?)
                       .join(" ")
                       .gsub(/\s{2,}/, " ")  # collapse multiple spaces
                       .strip

    text
  end

  def download_file(url)
    uri = URI.parse(url)
    extension = File.extname(uri.path)
    return nil unless %w[.pdf .csv .doc .docx].include?(extension)

    file_name = "#{SecureRandom.hex}#{extension}"
    file_path = TMP_DIR.join(file_name)


    URI.open(uri, "rb") do |remote_file|
      File.open(file_path, "wb") { |f| f.write(remote_file.read) }
    end

    file_path.to_s
  rescue => e
    Rails.logger.warn("CrError downloading file #{url}: #{e.message}")
    nil
  end
end
