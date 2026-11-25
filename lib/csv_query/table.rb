module CsvQuery
  class ParseError < StandardError; end

  class Table
    attr_reader :headers, :rows

    include Enumerable

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

    def each(&block)
      return enum_for(:each) unless block_given?
      @rows.each { |row| block.call(row.dup) }
      self
    end

    def select(*columns, &block)
      if block_given? && columns.empty?
        return Table.new(@headers, @rows.select { |row| block.call(row) })
      end

      cols = columns.flatten.map(&:to_s)
      unknown = cols - @headers
      raise ArgumentError, "unknown column(s): #{unknown.join(', ')}" unless unknown.empty?
      Table.new(cols, @rows.map { |r| cols.each_with_object({}) { |c, o| o[c] = r[c] } })
    end

    def where(expr = nil, &block)
      if block
        Table.new(@headers, @rows.select { |r| block.call(r) })
      elsif expr.nil?
        raise ArgumentError, "missing condition"
      else
        pred = Condition.parse(expr, @headers)
        Table.new(@headers, @rows.select { |r| pred.call(r) })
      end
    end

    alias filter where

    def reject(expr = nil, &block)
      if block
        Table.new(@headers, @rows.reject { |r| block.call(r) })
      elsif expr.nil?
        raise ArgumentError, "missing condition"
      else
        pred = Condition.parse(expr, @headers)
        Table.new(@headers, @rows.reject { |r| pred.call(r) })
      end
    end

    def find(expr = nil, &block)
      if expr.nil? && !block_given?
        return @rows.first&.dup
      end

      row = if block_given?
              @rows.find { |r| block.call(r) }
            elsif expr.nil?
              raise ArgumentError, "missing condition"
            else
              pred = Condition.parse(expr, @headers)
              @rows.find { |r| pred.call(r) }
            end
      row&.dup
    end

    def sort_by(column = nil, direction = :asc, &block)
      if block
        sorted = @rows.each_with_index.sort do |(ra, ia), (rb, ib)|
          cmp = (block.call(ra) <=> block.call(rb)) || 0
          cmp.zero? ? ia <=> ib : cmp
        end.map(&:first)
        return Table.new(@headers, sorted)
      end

      raise ArgumentError, "missing sort key" if column.nil?
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

    alias sort sort_by

    def distinct
      Table.new(@headers, @rows.uniq)
    end

    alias uniq distinct
    alias unique distinct

    def limit(n)
      return Table.new(@headers, @rows) if n.nil?
      count = n.to_i
      count = 0 if count < 0
      Table.new(@headers, @rows.first(count))
    end

    alias head limit
    alias take limit

    def offset(n)
      return Table.new(@headers, @rows) if n.nil?
      count = n.to_i
      count = 0 if count < 0
      Table.new(@headers, @rows.drop(count))
    end

    alias skip offset
    alias drop offset

    def reverse
      Table.new(@headers, @rows.reverse)
    end

    def tail(n)
      return Table.new(@headers, @rows) if n.nil?
      count = n.to_i
      count = 0 if count < 0
      count = @rows.size if count > @rows.size
      Table.new(@headers, @rows.last(count))
    end

    def first(n = nil)
      return @rows.first&.dup if n.nil?
      head(n)
    end

    def last(n = nil)
      return @rows.last&.dup if n.nil?
      tail(n)
    end

    def slice(start, length = nil)
      if start.is_a?(Range)
        range = start
        offset_count = if range.begin.nil?
                         0
                       else
                         i = range.begin.to_i
                         i += @rows.size if i < 0
                         i < 0 ? 0 : i
                       end
        return Table.new(@headers, []) if offset_count > @rows.size

        if range.end.nil?
          return offset(offset_count)
        end

        last_index = range.end.to_i
        last_index += @rows.size if last_index < 0
        last_index = @rows.size - 1 if last_index > @rows.size - 1
        count = last_index - offset_count + (range.exclude_end? ? 0 : 1)
        count = 0 if count < 0
        offset(offset_count).limit(count)
      else
        start_i = start.to_i
        if start_i < 0
          start_i += @rows.size
          return Table.new(@headers, []) if start_i < 0
        end
        return Table.new(@headers, []) if start_i > @rows.size

        len = length.nil? ? nil : length.to_i
        return Table.new(@headers, []) if !len.nil? && len < 0
        offset(start_i).limit(len)
      end
    end

    def [](index, length = nil)
      if index.is_a?(Range)
        slice(index)
      elsif index.is_a?(String) || index.is_a?(Symbol)
        col = index.to_s
        raise ArgumentError, "unknown column: #{col}" unless @headers.include?(col)
        pluck(col)
      elsif length.nil?
        i = index.to_i
        i += @rows.size if i < 0
        return nil if i < 0 || i >= @rows.size
        @rows[i]&.dup
      else
        slice(index, length)
      end
    end

    def group_by(key = nil, &block)
      raise ArgumentError, "missing group key" if key.nil? && !block_given?
      groups = Hash.new { |h, k| h[k] = [] }
      @rows.each do |row|
        value = block_given? ? block.call(row) : row[key.to_s]
        groups[value] << row
      end
      groups.transform_values { |rows| Table.new(@headers, rows) }
    end

    def join(other, on: nil, left_on: nil, right_on: nil, type: :inner)
      right = if other.is_a?(Table)
                other
              elsif other.is_a?(Array)
                inferred = []
                other.each do |row|
                  keys = row.is_a?(Hash) ? row.keys.map(&:to_s) : @headers
                  keys.each { |key| inferred << key unless inferred.include?(key) }
                end
                inferred = @headers.dup if inferred.empty?
                Table.new(inferred, other)
              else
                raise ArgumentError, "expected a Table or Array of rows"
              end

      left_key = left_on || on
      right_key = right_on || on
      if left_key.nil? && right_key.nil?
        common = @headers & right.headers
        raise ArgumentError, "missing join key" if common.empty?
        raise ArgumentError, "ambiguous join key: #{common.join(', ')}" if common.size > 1
        left_key = right_key = common.first
      else
        left_key = right_key if left_key.nil?
        right_key = left_key if right_key.nil?
      end
      left_key = left_key.to_s
      right_key = right_key.to_s

      raise ArgumentError, "unknown column: #{left_key}" unless @headers.include?(left_key)
      raise ArgumentError, "unknown column: #{right_key}" unless right.headers.include?(right_key)

      join_type = type.to_sym
      unless %i[inner left right full].include?(join_type)
        raise ArgumentError, "unknown join type: #{type}"
      end

      used_headers = @headers.dup
      right_output = {}
      right.headers.each do |header|
        next if header == right_key
        name = header
        if used_headers.include?(name)
          name = "#{header}_right"
          suffix = 2
          while used_headers.include?(name)
            name = "#{header}_right#{suffix}"
            suffix += 1
          end
        end
        used_headers << name
        right_output[header] = name
      end
      new_headers = @headers + right.headers.select { |header| header != right_key }.map { |header| right_output[header] }

      matched_right = {}
      result_rows = []

      @rows.each do |left_row|
        matches = right.rows.select { |right_row| join_keys_equal?(right_row[right_key], left_row[left_key]) }
        if matches.empty?
          result_rows << build_join_row(left_row, nil, right.headers, right_key, right_output, left_key) if join_type == :left || join_type == :full
        else
          matches.each do |right_row|
            result_rows << build_join_row(left_row, right_row, right.headers, right_key, right_output, left_key)
            matched_right[right_row.object_id] = true
          end
        end
      end

      if join_type == :right || join_type == :full
        right.rows.each do |right_row|
          next if matched_right[right_row.object_id]
          result_rows << build_join_row(nil, right_row, right.headers, right_key, right_output, left_key)
        end
      end

      Table.new(new_headers, result_rows)
    end

    def inner_join(other, on: nil, left_on: nil, right_on: nil)
      join(other, on: on, left_on: left_on, right_on: right_on, type: :inner)
    end

    def left_join(other, on: nil, left_on: nil, right_on: nil)
      join(other, on: on, left_on: left_on, right_on: right_on, type: :left)
    end

    def right_join(other, on: nil, left_on: nil, right_on: nil)
      join(other, on: on, left_on: left_on, right_on: right_on, type: :right)
    end

    def full_join(other, on: nil, left_on: nil, right_on: nil)
      join(other, on: on, left_on: left_on, right_on: right_on, type: :full)
    end

    def concat(other)
      other_rows = other.is_a?(Table) ? other.rows : Array(other)
      Table.new(@headers, @rows + other_rows.map { |r| normalize_row(r) })
    end

    alias + concat

    def count(*_args, &block)
      if block_given?
        @rows.count { |row| block.call(row) }
      else
        @rows.size
      end
    end

    alias size count
    alias length count

    def empty?
      @rows.empty?
    end

    def to_a
      @rows.map(&:dup)
    end

    def to_csv
      CsvQuery::Formatters.csv(self)
    end

    def to_json(*_args)
      CsvQuery::Formatters.json(self)
    end

    def pluck(column)
      col = column.to_s
      raise ArgumentError, "unknown column: #{col}" unless @headers.include?(col)
      @rows.map { |r| r[col] }
    end

    private

    def build_join_row(left_row, right_row, right_headers, right_key, right_output, left_key = nil)
      row = {}
      @headers.each { |header| row[header] = left_row ? left_row[header] : nil }
      if left_row.nil? && left_key && right_row
        row[left_key] = right_row[right_key]
      end
      right_headers.each do |header|
        next if header == right_key
        row[right_output[header]] = right_row ? right_row[header] : nil
      end
      row
    end

    def join_keys_equal?(a, b)
      return true if a.nil? && b.nil?
      return false if a.nil? || b.nil?
      a.to_s == b.to_s
    end

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
