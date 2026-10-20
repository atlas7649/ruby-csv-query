require "optparse"

module CsvQuery
  class CLI
    def self.run(argv)
      options = {
        format: "table", select: nil, where: [], sort: nil,
        distinct: false, count: false, limit: nil
      }
      parser = OptionParser.new do |o|
        o.banner = "Usage: csvq [options] [FILE]"
        o.on("-s", "--select COLS", "Comma-separated columns to keep") do |v|
          options[:select] = v.split(",").map(&:strip)
        end
        o.on("-w", "--where EXPR", "Filter expression (repeatable)") do |v|
          options[:where] << v
        end
        o.on("--sort COL", "Sort by column, append :desc") do |v|
          options[:sort] = v
        end
        o.on("-d", "--distinct", "Drop duplicate rows") { options[:distinct] = true }
        o.on("-c", "--count", "Print number of rows") { options[:count] = true }
        o.on("-n", "--limit N", Integer, "Limit output rows") do |v|
          options[:limit] = v
        end
        o.on("-f", "--format FMT", "table|csv|json") do |v|
          options[:format] = v
        end
        o.on("-v", "--version", "Print version") do
          puts "csvq #{VERSION}"
          exit
        end
        o.on("-h", "--help", "Show help") do
          puts o
          exit
        end
      end
      parser.parse!(argv)

      file = argv[0] || "-"
      table = Table.from_file(file)
      table = table.select(options[:select]) if options[:select]
      options[:where].each { |w| table = table.where(w) }
      if options[:sort]
        col, dir = options[:sort].split(":", 2)
        table = table.sort_by(col, dir == "desc" ? :desc : :asc)
      end
      table = table.distinct if options[:distinct]
      table = table.limit(options[:limit]) if options[:limit]

      if options[:count]
        puts table.rows.size
      else
        output = Formatters.format(table, options[:format])
        print output
        puts unless output.end_with?("\n")
      end
    rescue => e
      warn "csvq: #{e.message}"
      exit 1
    end
  end
end
