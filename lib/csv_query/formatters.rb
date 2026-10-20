module CsvQuery
  module Formatters
    def self.format(table, format)
      case format.to_s.downcase
      when "csv" then csv(table)
      when "json" then json(table)
      else table_format(table)
      end
    end

    def self.csv(table)
      return "" if table.headers.empty?
      CSV.generate do |csv|
        csv << table.headers
        table.rows.each { |r| csv << table.headers.map { |h| r[h] } }
      end
    end

    def self.json(table)
      table.rows.map { |r| table.headers.each_with_object({}) { |h, o| o[h] = r[h] } }.to_json
    end

    def self.table_format(table)
      return "" if table.headers.empty?
      widths = table.headers.map.with_index do |h, i|
        vals = table.rows.map { |r| r[h].to_s.length }
        [h.to_s.length, *vals].max
      end
      header_line = table.headers.map.with_index { |h, i| h.to_s.ljust(widths[i]) }.join("  ")
      separator = widths.map { |w| "-" * w }.join("  ")
      body = table.rows.map do |r|
        table.headers.map.with_index { |h, i| r[h].to_s.ljust(widths[i]) }.join("  ")
      end
      ([header_line, separator] + body).join("\n")
    end
  end
end
