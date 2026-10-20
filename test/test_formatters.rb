require "minitest/autorun"
require "csv_query"

class TestFormatters < Minitest::Test
  def setup
    @t = CsvQuery::Table.from_csv("name,age\nAlice,30\nBob,25\n")
  end

  def test_csv_roundtrip
    out = CsvQuery::Formatters.format(@t, "csv")
    assert_includes out, "name,age"
    assert_includes out, "Alice,30"
  end

  def test_json
    out = CsvQuery::Formatters.format(@t, "json")
    assert_equal [{"name" => "Alice", "age" => "30"}, {"name" => "Bob", "age" => "25"}], JSON.parse(out)
  end

  def test_table_has_header_and_separator
    out = CsvQuery::Formatters.format(@t, "table")
    lines = out.split("\n")
    assert_equal 4, lines.size
    assert_includes lines[1], "-"
  end
end
