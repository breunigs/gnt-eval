# extends the PESTOmr with some database related tools. Connecting to
# the database is handled by FunkyDBBits and its "dbh" function. Both
# FunkyDBBits and this extension assume that seee_config.rb has been
# loaded somewhere before.

class PESTDatabaseTools
  include FunkyDBBits

  # Exists the application if no connection could be made. Actual
  # connecting is handled in FunkyDBBits.rb
  def ensure_database_access
    if dbh.nil? || !dbh.connected?
	  puts "ERROR: Couldn’t open a database connection."
	  puts "Have a look at lib/seee_config.rb to correct the settings."
	  exit 1
	end
  end

  def set_debug_database
	puts "WARNING: Debug mode is enabled, writing to db.sqlite3 in working directory instead of real database."
	Seee::Config.external_database[:dbi_handler] = "SQLite3"
	Seee::Config.external_database[:database] = "#{@path}/db.sqlite3"
  end

  def list_available_tables
	tables = []
	x = case Seee::Config.external_database[:dbi_handler].downcase
	  when "sqlite3": "SELECT name FROM sqlite_master WHERE type='table'"
	  when "mysql":   "SHOW TABLES"
	  # via http://bytes.com/topic/postgresql/answers/172978-sql-command-list-tables#post672429
	  when "pg":      "select c.relname FROM pg_catalog.pg_class c
LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r','') AND n.nspname NOT IN ('pg_catalog', 'pg_toast')
AND pg_catalog.pg_table_is_visible(c.oid);"
	  else            raise("Unsupported database handler")
	end
	dbh.execute(x).each { |y| tables << y[0] }
	tables
  end
end
