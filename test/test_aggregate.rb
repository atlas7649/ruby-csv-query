require "minitest/autorun"
require "csv_query"

class TestAggregate < Minitest::Test
  CSV_TEXT = "name,age,city\nAlice,30,NYC\nBob,25,LA\nCharlie,30,NYC\n"

  def test_sum_column
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal 85, t.sum("age")
  end

  def test_sum_block
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal 85, t.sum { |row| row["age"].to_i }
  end

  def test_sum_transforms_values
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal 170, t.sum("age") { |value| value.to_i * 2 }
  end

  def test_average
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_in_delta 28.333333333333332, t.average("age"), 0.0001
    assert_in_delta 28.333333333333332, t.avg("age"), 0.0001
  end

  def test_minimum_and_maximum
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal "25", t.minimum("age")
    assert_equal "30", t.maximum("age")
  end

  def test_count_column
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_equal 3, t.count("age")
    assert_equal 2, t.count { |row| row["age"].to_i >= 30 }
  end

  def test_aggregates_with_block_grouping_key
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    groups = t.group_by("city")
    assert_equal 60, groups["NYC"].sum("age")
    assert_equal 25, groups["LA"].sum("age")
  end

  def test_aggregates_ignore_nil
    t = CsvQuery::Table.from_csv("id,val\n1,10\n2,\n3,30\n")
    assert_equal 40, t.sum("val")
  end

  def test_aggregate_unknown_column_raises
    t = CsvQuery::Table.from_csv(CSV_TEXT)
    assert_raises(ArgumentError) { t.sum("nope") }
    assert_raises(ArgumentError) { t.average("nope") }
    assert_raises(ArgumentError) { t.minimum("nope") }
    assert_raises(ArgumentError) { t.maximum("nope") }
    assert_raises(ArgumentError) { t.count("nope") }
  end

  def test_empty_aggregates
    t = CsvQuery::Table.from_csv("age\n")
    assert_equal 0, t.sum("age")
    assert_nil t.average("age")
    assert_nil t.minimum("age")
    assert_nil t.maximum("age")
  end
end
