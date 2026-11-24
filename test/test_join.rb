require "minitest/autorun"
require "csv_query"

class TestJoin < Minitest::Test
  def test_inner_join_infers_common_key
    left = CsvQuery::Table.from_csv("id,name\n1,Alice\n2,Bob\n")
    right = CsvQuery::Table.from_csv("id,city\n1,NYC\n2,LA\n")
    result = left.join(right)
    assert_equal %w[id name city], result.headers
    assert_equal %w[Alice Bob], result.rows.map { |r| r["name"] }
    assert_equal %w[NYC LA], result.rows.map { |r| r["city"] }
  end

  def test_join_explicit_keys
    left = CsvQuery::Table.from_csv("user_id,name\n1,Alice\n")
    right = CsvQuery::Table.from_csv("id,city\n1,NYC\n")
    result = left.join(right, left_on: "user_id", right_on: "id")
    assert_equal %w[user_id name city], result.headers
    assert_equal "NYC", result.rows.first["city"]
  end

  def test_left_join_includes_unmatched_rows
    left = CsvQuery::Table.from_csv("id,name\n1,Alice\n2,Bob\n")
    right = CsvQuery::Table.from_csv("id,city\n1,NYC\n")
    result = left.left_join(right, on: "id")
    assert_equal 2, result.rows.size
    assert_nil result.rows[1]["city"]
  end

  def test_right_join_includes_unmatched_rows
    left = CsvQuery::Table.from_csv("id,name\n1,Alice\n")
    right = CsvQuery::Table.from_csv("id,city\n1,NYC\n2,LA\n")
    result = left.right_join(right, on: "id")
    assert_equal 2, result.rows.size
    assert_nil result.rows[1]["name"]
    assert_equal "LA", result.rows[1]["city"]
  end

  def test_full_join_includes_unmatched_rows_from_both_tables
    left = CsvQuery::Table.from_csv("id,name\n1,Alice\n2,Bob\n")
    right = CsvQuery::Table.from_csv("id,city\n2,LA\n3,Chicago\n")
    result = left.full_join(right, on: "id")
    assert_equal 3, result.rows.size
    assert_equal ["Alice", "Bob", nil], result.rows.map { |r| r["name"] }
    assert_equal [nil, "LA", "Chicago"], result.rows.map { |r| r["city"] }
  end

  def test_join_suffixes_colliding_columns
    left = CsvQuery::Table.from_csv("id,name\n1,Alice\n")
    right = CsvQuery::Table.from_csv("id,name\n1,Bob\n")
    result = left.join(right, on: "id")
    assert_equal %w[id name name_right], result.headers
    assert_equal "Alice", result.rows.first["name"]
    assert_equal "Bob", result.rows.first["name_right"]
  end

  def test_join_accepts_array_of_rows
    left = CsvQuery::Table.from_csv("id,name\n1,Alice\n")
    result = left.join([{ "id" => "1", "city" => "NYC" }], on: "id")
    assert_equal "NYC", result.rows.first["city"]
  end

  def test_join_rejects_unknown_type
    left = CsvQuery::Table.from_csv("id,name\n1,Alice\n")
    right = CsvQuery::Table.from_csv("id,city\n1,NYC\n")
    assert_raises(ArgumentError) { left.join(right, on: "id", type: :cross) }
  end

  def test_join_rejects_unknown_key
    left = CsvQuery::Table.from_csv("id,name\n1,Alice\n")
    right = CsvQuery::Table.from_csv("id,city\n1,NYC\n")
    assert_raises(ArgumentError) { left.join(right, on: "missing") }
  end
end
