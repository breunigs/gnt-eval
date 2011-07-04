# extends the PESTOmr with some database related tools. Connecting to
# the database is handled by FunkyDBBits and its "dbh" function. Both
# FunkyDBBits and this extension assume that seee_config.rb has been
# loaded somewhere before.

cdir = File.dirname(__FILE__)
require cdir + '/helper.misc.rb'

class PESTDatabaseTools
  include FunkyDBBits

  # Exists the application if no connection could be made. Actual
  # connecting is handled in FunkyDBBits.rb
  def ensure_database_access
    if dbh.nil? || !dbh.connected?
      debug "ERROR: Couldn’t open a database connection."
      debug "Have a look at lib/seee_config.rb to correct the settings."
      exit 1
    end
  end

  def set_debug_database
    debug "WARNING: Debug mode is enabled, writing to db.sqlite3 in working directory instead of real database." if @verbose
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

  # creates the database table as defined by the given YAML document.
  def create_table_if_required(f)
    # Note that the barcode is only unique for each CourseProf, but
    # not for each sheet. That's why path is used as unique key.
    q = "CREATE TABLE #{f.db_table} ("

    f.questions.each do |quest|
      next if quest.db_column.nil?
      if quest.db_column.is_a?(Array)
        quest.db_column.each do |a|
          q << "#{a} INTEGER, "
        end
      else
        q << "#{quest.db_column} INTEGER, "
      end
    end

    q << "path VARCHAR(255) NOT NULL UNIQUE, "
    q << "barcode INTEGER default NULL, "
    q << "abstract_form TEXT default NULL "
    q << ");"

    begin
      dbh.do(q)
      debug "Created #{f.db_table}"
    rescue => e
      # There is no proper method supported by MySQL, PostgreSQL and
      # SQLite to find out if a table already exists. So, if above
      # command failed because the table exists, selecting something
      # from it should work fine. If it doesn’t, print an error message.
      begin
        dbh.do("SELECT * FROM #{f.db_table}")
      rescue
        debug "Note: Creating table #{f.db_table} failed. Possible causes:"
        debug "* SQL backend is down/misconfigured"
        debug "* used SQL query is not supported by your SQL backend"
        debug "Query was #{q}"
        debug "Error: "
        pp e
        exit
      end
    end
  end
end
