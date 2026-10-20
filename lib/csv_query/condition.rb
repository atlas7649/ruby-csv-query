module CsvQuery
  class Condition
    OPS = [">=", "<=", "!=", "<>", "==", "=", ">", "<", "contains", "starts_with", "ends_with", "=~", "~"].freeze

    def self.parse(expr, headers)
      expr = expr.to_s.strip
      match = nil
      OPS.sort_by(&:length).reverse.each do |op|
        re = /\A\s*(.+?)\s*#{Regexp.escape(op)}\s*(.+?)\s*\z/im
        m = expr.match(re)
        next unless m
        col = unquote(m[1].strip)
        val = unquote(m[2].strip)
        unless headers.map(&:to_s).include?(col)
          raise ArgumentError, "unknown column: #{col}"
        end
        match = [col, op.downcase, val]
        break
      end
      raise ArgumentError, "invalid condition: #{expr}" unless match
      col, op, val = match
      ->(row) { compare(row[col.to_s], op, val) }
    end

    def self.compare(actual, op, expected)
      case op
      when "=", "==" then eq?(actual, expected)
      when "!=", "<>" then !eq?(actual, expected)
      when ">", "<", ">=", "<=" then numeric_compare(actual, expected, op)
      when "contains" then actual.to_s.downcase.include?(expected.to_s.downcase)
      when "starts_with" then actual.to_s.downcase.start_with?(expected.to_s.downcase)
      when "ends_with" then actual.to_s.downcase.end_with?(expected.to_s.downcase)
      when "=~", "~" then actual.to_s.match?(Regexp.new(expected.to_s))
      else false
      end
    end

    def self.eq?(a, b)
      if numeric?(a) && numeric?(b)
        Float(a) == Float(b)
      else
        a.to_s == b.to_s
      end
    end

    def self.numeric_compare(a, b, op)
      an = numeric?(a) ? Float(a) : nil
      bn = numeric?(b) ? Float(b) : nil
      cmp = if an && bn
              an <=> bn
            else
              a.to_s <=> b.to_s
            end
      case op
      when ">" then cmp > 0
      when "<" then cmp < 0
      when ">=" then cmp >= 0
      when "<=" then cmp <= 0
      else false
      end
    end

    def self.numeric?(v)
      return false if v.nil?
      Float(v)
      true
    rescue ArgumentError, TypeError
      false
    end

    def self.unquote(s)
      s = s.strip
      if (s.start_with?("\"") && s.end_with?("\"")) || (s.start_with?("'") && s.end_with?("'"))
        s[1..-2]
      else
        s
      end
    end
  end
end
