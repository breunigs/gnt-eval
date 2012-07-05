# encoding: utf-8

# extends the PESTOmr with some database related tools. Connecting to
# the database is handled by lib/result_tools.rb.

cdir = File.dirname(__FILE__)
require cdir + '/helper.misc.rb'
require cdir + '/../web/app/lib/result_tools.rb'

class PESTDatabaseTools
  RT = ResultTools.instance

  def set_debug_database
    debug "WARNING: Debug mode is enabled, writing to db.sqlite3 in working directory instead of real database." if @verbose && !@test_mode
    Seee::Config.external_database[:dbi_handler] = "SQLite3"
    Seee::Config.external_database[:database] = "#{@path}/db.sqlite3"
    RT.reconnect_to_database
  end

  def list_available_tables
    tables = []
    x = case Seee::Config.external_database[:dbi_handler].downcase
      when "sqlite3" then "SELECT name FROM sqlite_master WHERE type='table'"
      when "mysql"   then "SHOW TABLES"
      # via http://bytes.com/topic/postgresql/answers/172978-sql-command-list-tables#post672429
      when "pg"      then "select c.relname FROM pg_catalog.pg_class c
  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE c.relkind IN ('r','') AND n.nspname NOT IN ('pg_catalog', 'pg_toast')
  AND pg_catalog.pg_table_is_visible(c.oid);"
      else            raise("Unsupported database handler")
    end
    RT.custom_query(x).each { |y| tables << y.values[0] }
    tables
  end

  # creates the database table as defined by the given YAML document.
  def create_table_if_required(f)
    return if RT.table_exists?(f.db_table)
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
        txt_col = quest.multi? ? quest.db_column.last : quest.db_column
        q << "#{txt_col}_text VARCHAR(250), " if quest.last_is_textbox?
      end
    end

    q << "path VARCHAR(255) NOT NULL UNIQUE, "
    q << "barcode INTEGER default NULL, "
    q << "abstract_form TEXT default NULL "
    q << ");"

    begin
      RT.custom_query_no_result(q)
      debug "Created #{f.db_table}"
    rescue => e
      # There is no proper method supported by MySQL, PostgreSQL and
      # SQLite to find out if a table already exists. So, if above
      # command failed because the table exists, selecting something
      # from it should work fine. If it doesn’t, print an error message.
      begin
        RT.custom_query_no_result("SELECT * FROM #{f.db_table}")
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
