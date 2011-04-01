# extends the PESTOmr with some database related tools. Connecting to
# the database is handled by FunkyDBBits and its "dbh" function. Both
# FunkyDBBits and this extension assume that seee_config.rb has been
# loaded somewhere before.

class PESTOmr
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
end
