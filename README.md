# ruby-csv-query

A small, dependency-free Ruby command-line tool and library for querying CSV
files. Select columns, filter rows with simple conditions, sort, deduplicate,
limit, count, and render results as an aligned table, CSV, or JSON.

No external gems are required; only the Ruby standard library is used.

## Installation

Clone the repository and make the CLI executable:

```sh
git clone https://github.com/atlas7649/ruby-csv-query.git
cd ruby-csv-query
chmod +x bin/csvq
```

Optionally symlink `bin/csvq` onto your `PATH`.

## Usage

```sh
# Print a CSV as an aligned table
csvq data.csv

# Select columns
csvq data.csv --select name,age

# Filter rows (repeatable, combined with AND)
csvq data.csv --where "age >= 30" --where "city contains york"

# Sort (append :desc for descending)
csvq data.csv --sort age:desc

# Distinct rows, limited
csvq data.csv --distinct --limit 5

# Count matching rows
csvq data.csv --where "status = active" --count

# Output formats
csvq data.csv --format csv
csvq data.csv --format json

# Read from stdin
cat data.csv | csvq - --select name
```

### Condition syntax

`COLUMN OP VALUE`, where `OP` is one of `=`, `==`, `!=`, `<>`, `>`, `<`,
`>=`, `<=`, `contains`, `starts_with`, `ends_with`, `=~`. Values may be
quoted with single or double quotes. Comparisons are numeric when both sides
parse as numbers.

## Library usage

```ruby
require "csv_query"

table = CsvQuery::Table.from_file("data.csv")
result = table.select(%w[name age])
             .where("age >= 30")
             .sort_by("age", :desc)
             .limit(10)
puts CsvQuery::Formatters.format(result, "json")
```

## Tests

```sh
rake test
# or
ruby -Ilib test/test_table.rb
```

## License

MIT
