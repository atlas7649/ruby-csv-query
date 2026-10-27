module CsvQuery
  class ParseError < StandardError; end

  class Table
    attr_reader :headers, :rows

    def initialize(headers, rows)
      @headers = (headers || []).map(&:to_s)
      @rows = (rows || []).map { |r| normalize_row(r) }
    end

    def self.from_csv(text)
      text = text.to_s.sub(/\A\uFEFF/, "")
      parsed = CSV.parse(text, headers: true, skip_blanks: true)
      headers = parsed.respond_to?(:headers) ? parsed.headers : nil
      headers = [] if headers.nil?
      rows = parsed.respond_to?(:map) ? parsed.map { |r| headers.each_with_index.each_with_object({}) { |(h, i), o| o[h.to_s] = r[i] } } : []
      new(headers, rows)
    rescue CSV::MalformedCSVError, ArgumentError, EncodingError => e
      raise ParseError, e.message
    end

    def self.from_file(path)
      text = path == "-" ? $stdin.binmode.read : File.binread(path)
      text = text.to_s.dup.force_encoding("UTF-8")
      text = text.encode("UTF-8", invalid: :replace, undef: :replace)
      from_csv(text)
    end

    def select(columns)
      cols = columns.map(&:to_s)
      unknown = cols - @headers
      raise ArgumentError, "unknown column(s): #{unknown.join(', ')}" unless unknown.empty?
      Table.new(cols, @rows.map { |r| cols.each_with_object({}) { |c, o| o[c] = r[c] } })
    end

    def where(expr)
      pred = Condition.parse(expr, @headers)
      Table.new(@headers, @rows.select { |r| pred.call(r) })
    end

    def sort_by(column, direction = :asc)
      col = column.to_s
      raise ArgumentError, "unknown column: #{col}" unless @headers.include?(col)
      desc = direction.to_sym == :desc
      sorted = @rows.each_with_index.sort do |(ra, ia), (rb, ib)|
        cmp = (sort_key(ra[col]) <=> sort_key(rb[col])) || 0
        cmp = -cmp if desc && !cmp.zero?
        cmp.zero? ? ia <=> ib : cmp
      end.map(&:first)
      Table.new(@headers, sorted)
    end

    def distinct
      Table.new(@headers, @rows.uniq)
    end

    def limit(n)
      return Table.new(@headers, @rows) if n.nil?
      count = n.to_i
      count = 0 if count < 0
      Table.new(@headers, @rows.first(count))
    end

    def offset(n)
      return Table.new(@headers, @rows) if n.nil?
      count = n.to_i
      count = 0 if count < 0
      Table.new(@headers, @rows.drop(count))
    end

    def count
      @rows.size
    end

    def pluck(column)
      col = column.to_s
      raise ArgumentError, "unknown column: #{col}" unless @headers.include?(col)
      @rows.map { |r| r[col] }
    end

    private

    def normalize_row(r)
      if r.is_a?(Hash)
        r.each_with_object({}) { |(k, v), o| o[k.to_s] = v }
      else
        @headers.each_with_index.each_with_object({}) { |(h, i), o| o[h.to_s] = r[i] }
      end
    end

    def sort_key(v)
      if v.nil? || v.to_s.strip.empty?
        [0, ""]
      elsif Condition.numeric?(v)
        if v.to_s.strip.match?(/\A[+-]?\d+\z/)
          begin
            [1, Integer(v.to_s.strip, 10)]
          rescue ArgumentError, TypeError
            [1, Float(v)]
          end
        else
          [1, Float(v)]
        end
      else
        [2, v.to_s.downcase]
      end
    end
  end
end
