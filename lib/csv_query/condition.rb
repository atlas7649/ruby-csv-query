module CsvQuery
  class Condition
    OPS = [">=", "<=", "!=", "<>", "==", "=", ">", "<", "contains", "starts_with", "ends_with", "=~", "~"].freeze

    def self.parse(expr, headers)
      expr = expr.to_s.strip
      headers = (headers || []).map(&:to_s)
      # Try longest operators first. Keep the original OPS order as a stable
      # tie-breaker so equal-length operators are always tried consistently.
      ordered_ops = OPS.each_with_index.sort_by { |op, i| [-op.length, i] }.map(&:first)

      # Prefer columns that are actually present. This prevents a value that
      # contains operator characters from being mistaken for part of the column.
      headers.sort_by { |h| -h.length }.each do |col|
        next if col.empty?
        [col, "\"#{col}\"", "'#{col}'"].each do |needle|
          ordered_ops.each do |op|
            re = /\A\s*#{Regexp.escape(needle)}\s*#{Regexp.escape(op)}\s*(.+?)\s*\z/im
            m = expr.match(re)
            next unless m
            val = unquote(m[1].strip)
            return ->(row) { compare(row[col], op.downcase, val) }
          end
        end
      end

      unknown_column = nil
      ordered_ops.each do |op|
        re = /\A\s*(.+?)\s*#{Regexp.escape(op)}\s*(.+?)\s*\z/im
        m = expr.match(re)
        next unless m
        col = unquote(m[1].strip)
        val = unquote(m[2].strip)
        unless headers.include?(col)
          unknown_column ||= col
          next
        end
        return ->(row) { compare(row[col.to_s], op.downcase, val) }
      end

      raise ArgumentError, "unknown column: #{unknown_column}" if unknown_column
      raise ArgumentError, "invalid condition: #{expr}"
    end

    def self.compare(actual, op, expected)
      case op
      when "=", "==" then eq?(actual, expected)
      when "!=", "<>" then !eq?(actual, expected)
      when ">", "<", ">=", "<=" then numeric_compare(actual, expected, op)
      when "contains" then actual.to_s.downcase.include?(expected.to_s.downcase)
      when "starts_with" then actual.to_s.downcase.start_with?(expected.to_s.downcase)
      when "ends_with" then actual.to_s.downcase.end_with?(expected.to_s.downcase)
      when "=~", "~" then regex_match?(actual, expected)
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
      Float(v).finite?
    rescue ArgumentError, TypeError
      false
    end

    def self.regex_match?(actual, expected)
      actual.to_s.match?(Regexp.new(expected.to_s))
    rescue RegexpError, ArgumentError, Encoding::CompatibilityError, EncodingError
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
