require "minitest/autorun"
require "csv_query"

class TestTable < Minitest::Test
  CSV_TEXT = "name,age,city\nAlice,30,NYC\nBob,25,LA\nCharlie,30,NYC\n"

  def test_from_csv_parses_headers_and_rows
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal %w[name age city], t.headers
    assert_equal 3, t.rows.size
    assert_equal "Alice", t.rows[0]["name"]
  end

  def test_select_columns
    t = CsvQuery::Table.from_csv(CSV_TEXT).select(%w[name age])
    assert_equal %w[name age], t.headers
    assert_equal "Alice", t.rows[0]["name"]
    assert_nil t.rows[0]["city"]
  end

  def test_select_unknown_raises
    assert_raises(ArgumentError) do
      CsvQuery::Table.from_csv(CSV_TEXT).select(%w[nope])
    end
  end

  def test_where_numeric
    t = CsvQuery::Table.from_csv(CSV_TEXT).where("age >= 30")
    assert_equal 2, t.rows.size
  end

  def test_where_contains
    t = CsvQuery::Table.from_csv(CSV_TEXT).where("city contains Y")
    assert_equal 2, t.rows.size
  end

  def test_where_block
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    result = t.where { |row| row["age"].to_i >= 30 }
    assert_equal %w[Alice Charlie], result.rows.map { |r| r["name"] }
    assert_equal 3, t.rows.size
  end

  def test_filter_alias
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    result = t.filter("city = LA")
    assert_equal %w[Bob], result.rows.map { |r| r["name"] }
  end

  def test_reject_string
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    result = t.reject("city = NYC")
    assert_equal %w[Bob], result.rows.map { |r| r["name"] }
  end

  def test_reject_block
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    result = t.reject { |row| row["age"].to_i >= 30 }
    assert_equal %w[Bob], result.rows.map { |r| r["name"] }
  end

  def test_find_string
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    row = t.find("name = Bob")
    assert_equal "Bob", row["name"]
    assert_nil t.find("name = Zed")
  end

  def test_find_block
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    row = t.find { |r| r["age"].to_i < 26 }
    assert_equal "Bob", row["name"]
  end

  def test_find_without_argument_returns_first_row
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal "Alice", (t.find)["name"]
  end

  def test_sort_desc
    t = CsvQuery::Table.from_csv(CSV_TEXT).sort_by("age", :desc)
    assert_equal "30", t.rows[0]["age"]
  end

  def test_sort_stable_preserves_original_order_for_ties
    t = CsvQuery::Table.from_csv("name,age\nAlice,30\nBob,30\nCharlie,25\n")
    asc = t.sort_by("age")
    assert_equal %w[Charlie Alice Bob], asc.rows.map { |r| r["name"] }
    desc = t.sort_by("age", :desc)
    assert_equal %w[Alice Bob Charlie], desc.rows.map { |r| r["name"] }
  end

  def test_sort_by_block
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    result = t.sort_by { |row| row["age"].to_i }
    assert_equal %w[Bob Alice Charlie], result.rows.map { |r| r["name"] }
  end

  def test_distinct
    t = CsvQuery::Table.from_csv(CSV_TEXT).distinct
    assert_equal 3, t.rows.size
    t2 = CsvQuery::Table.from_csv("a,b\n1,2\n1,2\n").distinct
    assert_equal 1, t2.rows.size
  end

  def test_limit
    t = CsvQuery::Table.from_csv(CSV_TEXT).limit(2)
    assert_equal 2, t.rows.size
  end

  def test_limit_nil_returns_all_rows
    t = CsvQuery::Table.from_csv(CSV_TEXT).limit(nil)
    assert_equal 3, t.rows.size
  end

  def test_limit_negative_returns_empty
    t = CsvQuery::Table.from_csv(CSV_TEXT).limit(-1)
    assert_equal 0, t.rows.size
  end

  def test_offset
    t = CsvQuery::Table.from_csv(CSV_TEXT).offset(1)
    assert_equal 2, t.rows.size
    assert_equal "Bob", t.rows[0]["name"]
  end

  def test_offset_nil_returns_all_rows
    t = CsvQuery::Table.from_csv(CSV_TEXT).offset(nil)
    assert_equal 3, t.rows.size
  end

  def test_offset_negative_returns_all_rows
    t = CsvQuery::Table.from_csv(CSV_TEXT).offset(-1)
    assert_equal 3, t.rows.size
  end

  def test_pluck
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal %w[Alice Bob Charlie], t.pluck("name")
    assert_equal %w[30 25 30], t.pluck(:age)
  end

  def test_pluck_unknown_raises
    assert_raises(ArgumentError) do
      CsvQuery::Table.from_csv(CSV_TEXT).pluck("nope")
    end
  end

  def test_reverse
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    reversed = t.reverse
    assert_equal %w[Charlie Bob Alice], reversed.rows.map { |r| r["name"] }
    assert_equal 3, t.rows.size
  end

  def test_head
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal %w[Alice Bob], t.head(2).rows.map { |r| r["name"] }
    assert_equal 3, t.rows.size
  end

  def test_head_nil_returns_all_rows
    t = CsvQuery::Table.from_csv(CSV_TEXT).head(nil)
    assert_equal 3, t.rows.size
  end

  def test_tail
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal %w[Bob Charlie], t.tail(2).rows.map { |r| r["name"] }
    assert_equal 3, t.rows.size
  end

  def test_tail_nil_returns_all_rows
    t = CsvQuery::Table.from_csv(CSV_TEXT).tail(nil)
    assert_equal 3, t.rows.size
  end

  def test_tail_negative_returns_empty
    t = CsvQuery::Table.from_csv(CSV_TEXT).tail(-1)
    assert_equal 0, t.rows.size
  end

  def test_tail_larger_than_row_count_returns_all_rows
    t = CsvQuery::Table.from_csv(CSV_TEXT).tail(10)
    assert_equal 3, t.rows.size
  end

  def test_slice_with_offset_and_length
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal %w[Bob Charlie], t.slice(1, 2).rows.map { |r| r["name"] }
  end

  def test_slice_with_range
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal %w[Bob Charlie], t.slice(1..2).rows.map { |r| r["name"] }
    assert_equal %w[Alice Bob], t.slice(0...2).rows.map { |r| r["name"] }
  end

  def test_slice_without_length_returns_remaining_rows
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal %w[Bob Charlie], t.slice(1).rows.map { |r| r["name"] }
  end

  def test_slice_negative_offset
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal %w[Charlie], t.slice(-1, 1).rows.map { |r| r["name"] }
    assert_equal %w[Bob Charlie], t.slice(1..-1).rows.map { |r| r["name"] }
    assert_equal %w[Alice Bob], t.slice(0...-1).rows.map { |r| r["name"] }
  end

  def test_take_and_skip_aliases
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal 2, t.take(2).rows.size
    assert_equal "Bob", t.skip(1).rows[0]["name"]
  end

  def test_first_without_argument_returns_first_row
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    row = t.first
    assert_equal "Alice", row["name"]
    assert_equal 3, t.rows.size
  end

  def test_first_with_argument_returns_table
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal %w[Alice Bob], t.first(2).rows.map { |r| r["name"] }
  end

  def test_last_without_argument_returns_last_row
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    row = t.last
    assert_equal "Charlie", row["name"]
    assert_equal 3, t.rows.size
  end

  def test_last_with_argument_returns_table
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal %w[Bob Charlie], t.last(2).rows.map { |r| r["name"] }
  end

  def test_drop_alias
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal "Bob", t.drop(1).rows[0]["name"]
  end

  def test_size_length_empty_and_to_a
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal 3, t.size
    assert_equal 3, t.length
    refute t.empty?
    assert_equal 3, t.to_a.size
    assert CsvQuery::Table.from_csv("").empty?
  end

  def test_each_yields_rows
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    names = []
    t.each { |row| names << row["name"] }
    assert_equal %w[Alice Bob Charlie], names
  end

  def test_map
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal %w[Alice Bob Charlie], t.map { |row| row["name"] }
  end

  def test_select_with_block
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    result = t.select { |row| row["age"].to_i >= 30 }
    assert_equal %w[Alice Charlie], result.rows.map { |r| r["name"] }
  end

  def test_count_with_block
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal 2, t.count { |row| row["age"].to_i >= 30 }
  end

  def test_from_empty
    t = CsvQuery::Table.from_csv("")
    assert_equal [], t.headers
    assert_equal [], t.rows
  end
end
