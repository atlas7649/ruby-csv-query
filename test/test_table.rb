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

  def test_limit_negative_returns_empty
    t = CsvQuery::Table.from_csv(CSV_TEXT).limit(-1)
    assert_equal 0, t.rows.size
  end

  def test_from_empty
    t = CsvQuery::Table.from_csv("")
    assert_equal [], t.headers
    assert_equal [], t.rows
  end
end
