module Embedding
  class DocumentExtractor
    def self.extract(file_path)
      case File.extname(file_path)
      when ".pdf"  then extract_pdf(file_path)
      when ".csv"  then extract_csv(file_path)
      when ".docx" then extract_docx(file_path)
      else ""
      end
    end

    def self.extract_pdf(file_path)
      reader = PDF::Reader.new(file_path)
      reader.pages.map(&:text).join("\n")
    rescue => e
      Rails.logger.warn("PDF extraction failed: #{e.message}")
      ""
    end

    def self.extract_csv(file_path)
      csv = Roo::Spreadsheet.open(file_path)
      csv.each.map { |row| row.join(" ") }.join("\n")
    rescue => e
      Rails.logger.warn("CSV extraction failed: #{e.message}")
      ""
    end

    def self.extract_docx(file_path)
      doc = Docx::Document.open(file_path)
      doc.paragraphs.map(&:text).join("\n")
    rescue => e
      Rails.logger.warn("DOCX extraction failed: #{e.message}")
      ""
    end
  end
end