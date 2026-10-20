require "minitest/autorun"
require "csv_query"

class TestCondition < Minitest::Test
  def test_equality_numeric
    pred = CsvQuery::Condition.parse("age = 30", %w[age name])
    assert pred.call("age" => "30")
    refute pred.call("age" => "25")
  end

  def test_inequality
    pred = CsvQuery::Condition.parse("name != Bob", %w[name])
    assert pred.call("name" => "Alice")
    refute pred.call("name" => "Bob")
  end

  def test_starts_ends
    p1 = CsvQuery::Condition.parse("name starts_with Al", %w[name])
    assert p1.call("name" => "Alice")
    p2 = CsvQuery::Condition.parse("name ends_with ce", %w[name])
    assert p2.call("name" => "Alice")
  end

  def test_regex
    pred = CsvQuery::Condition.parse("name =~ ^A", %w[name])
    assert pred.call("name" => "Alice")
    refute pred.call("name" => "Bob")
  end

  def test_quoted_value
    pred = CsvQuery::Condition.parse("city = \"New York\"", %w[city])
    assert pred.call("city" => "New York")
  end

  def test_unknown_column_raises
    assert_raises(ArgumentError) do
      CsvQuery::Condition.parse("nope = 1", %w[age])
    end
  end
end
