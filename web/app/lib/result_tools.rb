# contains useful utilities to work with result data and transform it
# in into a more suitable way to display. The actual display routines
# are located in text/results/. I.e. database and TeX handling.
# The ResultTools class is shared globally, access it using
# ResultTools.instance

require "rubygems"
require "singleton"
require "dbi"

cdir = File.dirname(__FILE__)
require cdir + "/seee_config.rb"

class ResultTools
  # only allow one instance of this class
  include Singleton

  # adds the variables that are available when designing the form.
  # By default, only the form does have these variables, however since
  # questions may refer to them (e.g. \lect{} to get the lecturer’s
  # name) they should be included in the results as well.
  # Currently only the lecturer’s name is supported; therefore it only
  # makes sense to define it if a CourseProf class is given. Otherwise
  # the commands will be mis-formed so TeX fails instead of producing
  # broken results.
  def include_form_variables(course_prof)
    b = "\n"
    if course_prof.is_a?(CourseProf)
      b << "\\def\\lect{#{course_prof.prof.fullname}\n"
      b << "\\def\\lectLAst{#{course_prof.prof.lastname}\n"
    else
      b << "\\def\\lect{\\variablesOutOfScopeErr}\n"
      b << "\\def\\lectLast{\\variablesOutOfScopeErr}\n"
    end
    b
  end

  # returns a TeX-string for a small headline
  def small_header(title)
    ERB.new(load_tex("small_header")).result(binding)
  end

  # returns a TeX-string which include all generated sample sheets. Also
  # adds the footer which ends the TeX document.
  def sample_sheets_and_footer(forms)
    path = File.join(Rails.root, "../tmp/sample_sheets/sample_")
    sample_sheets = {}

    forms.each do |f|
      f.languages.each do |l|
        sample_sheets["#{path}#{f.id}_#{l}.pdf"] = { :name => f.name, :lang => I18n.t(l) }
      end
    end

    ERB.new(load_tex("footer")).result(binding)
  end

  # returns true if the given table exists, false otherwise
  def table_exists?(table)
    report_valid_name?(table)
    sth = @dbh.prepare("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ?")
    sth.execute(table)
    r = sth.fetch
    sth.finish
    !r.nil?
  end

  # Counts the amount of rows for the given hash as well as the average
  # and standard deviation for the given values. Rows with invalid
  # values (i.e. only 0 < values < 99) are ignored.
  def count_avg_stddev(table, column, where_hash = {})
    return -1 unless report_valid_name?(table) && report_valid_name?(column)
    clause = hash_to_where_clause(where_hash)
    return -1 if clause.nil?
    sql = "SELECT COUNT(#{column}) AS count, "
    sql << "        AVG(#{column}) AS avg, "
    sql << "     STDDEV(#{column}) AS stddev "
    sql << "FROM #{table} WHERE #{clause}"
    # exclude invalid values
    sql << "AND 0 < #{column} AND #{column} < 99"
    r = custom_query(sql, where_hash.values, true)
    return r[:count], r[:avg], r[:stddev]
  end

  # Counts the amount of rows for the given hash. It is processed in the
  # form of key IN (value[,value[, …]]). Returns -1 if there were errors,
  # e.g. if one of the names contains invalid chars.
  # If table is an array the query is run for each of the tables
  # separately, i.e. the tables are not joined.
  def count(table, where_hash = {})
    return -1 unless report_valid_name?(table)
    return table.uniq.collect {|t| count(t, where_hash) }.sum if table.is_a?(Array)
    unless table_exists?(table)
      warn "Given table `#{table}` does NOT exist."
      warn "Assuming this means there are no sheets for that table."
      warn "Returning 0 now."
      return 0
    end
    sql = "SELECT COUNT(*) AS count FROM #{table} WHERE"
    clause = hash_to_where_clause(where_hash)
    return -1 if clause.nil?
    sql << clause
    r = custom_query(sql, where_hash.values, true)
    r[:count]
  end

  # runs a custom query against the result-database. Returns the all
  # results as an array of DBI::Row and instantly finishes the statement.
  # Therefore you don’t want to use this if you gather large values.
  def custom_query(query, values, first_row = false)
    check_query(query, values)
    q = @dbh.prepare(query)
    begin
      q.execute(*values.flatten)
      v = first_row ? q.fetch : q.fetch_all
    rescue DBI::DatabaseError => e
      warn ""
      warn "Query:  #{query}"
      warn "Values: #{values.join(", ")}"
      raise "SQL-Error (Err-Code: #{e.err}; Err-Msg: #{e.errstr}; SQLSTATE: #{e.state}). Query was: #{query}"
    ensure
      q.finish
    end
    v # return the result; or nil if an error occurred
  end

  # initializes a database connection. Since this class includes the
  # singleton mixin, only one connection will be opened per Ruby
  # instance.
  def initialize
    sced = Seee::Config.external_database
    start = Time.now
    print "Connecting to result database took "
    @dbh = DBI.connect(
      "DBI:#{sced[:dbi_handler]}:#{sced[:database]}:#{sced[:host]}",
      sced[:username],
      sced[:password])
    puts "#{Time.now - start} seconds"

    @tex = {}
  end

  # evaluates a given question with the sheets matching special_where.
  # If the question type prints a comparison value it will be compared
  # against all sheets that can be found in compare_where. Note that
  # statistical values are only available to single choice questions
  # since they don’t make too much sense for multiple choice questions.
  # The answer count is calculated for the special_where for both
  # single and multiple choice questions. The answers for compare_where
  # are not counted until they are really required (send patches).
  def eval_question(table, question, special_where, compare_where)
    if question.multi?
      eval_question_multi(table, question, special_where, compare_where)
    else
      eval_question_single(table, question, special_where, compare_where)
    end
  end

  # Loads a tex.erb file from disk and then stores it in memory. If
  # there is no file of that name a warning is printed to STDERR and an
  # error message is returned in place of the ERB code. Sample usage:
  # ERB.new(load_tex("some_file_name")).result(binding)
  # This loads the TeX file, executes ERB in the current context (i.e.
  # all variables you can access may be accessed by ERB) and returns the
  # result as string. The file must be located in the tex/results folder
  # and .tex.erb will be added automatically.
  def load_tex(name)
    if @tex[name].nil?
      path = RAILS_ROOT + "/../tex/results/#{name}.tex.erb"
      if File.exist?(path)
        @tex[name] = IO.read(path)
      else
        warn "There is no result-TeX-snippet called #{name}."
        warn "Are you sure the file exists at #{path}?"
        warn "Returning warning string instead."
        @tex[name] = "\n\nERROR: No TeX code found for results/#{name}.tex.erb\n\n"
      end
    end

    @tex[name]
  end

  # Loads all .def.tex files located in the tex/results folder. These
  # files contain commands that do not change and therefore only need to
  # be included once. ERB is not supported.
  def load_tex_definitions
    b = ""
    Dir.glob(RAILS_ROOT + "/../tex/results/*.def.tex") do |file|
      b << IO.read(file)
    end
    b
  end

  private ##############################################################

  # See eval_question; handles single choice questions only
  def eval_question_single(table, q, special_where, compare_where)
    # collect data for this question
    answ = get_answer_counts(table, q, special_where)
    sc, sa, ss = count_avg_stddev(table, q.db_column, special_where)
    # exit early if there is not enough data. Note that this is
    # different from the minimum required sheets: If enough sheets have
    # been handed in, but everyone checked “not specified” you still
    # would want to include that question. Privacy protection is handled
    # in each model’s eval_block.
    if sc.nil? || sc <= 0
      return ERB.new(load_tex("both_too_few_answers")).result(binding)
    end

    # load comparison data
    cc, ca, cs = count_avg_stddev(table, q.db_column, compare_where)

    b = ''
    [q.visualizer].flatten.each do |vis|
      b << ERB.new(load_tex("single_#{vis}")).result(binding)
    end
    b
  end

  # See eval_question; handles multiple choice questions only
  def eval_question_multi(table, q, special_where, compare_where)
    answ = get_answer_counts(table, q, special_where)
    sc = answ.values_at(*(1..q.size)).total
    # see comment in eval_question_single
    if sc.nil? || sc <= 0
      return ERB.new(load_tex("both_too_few_answers")).result(binding)
    end

    b = ''
    [q.visualizer].flatten.each do |vis|
      b << ERB.new(load_tex("multi_#{vis}")).result(binding)
    end
    b
  end

  # gets the amount of checks each answer received. Returns a hash with
  # choice (i.e. index+1) and the boxes’ text mapped to the count. The
  # latter is only available for boxes that actually have text. Invalid
  # answers (i.e. not enough or too few checkmarks) are counted in the
  # :invalid entry. Regardless if enabled, the count of special «no
  # answer» box is available via :abstentions. The amount of answers
  # than can be used to evaluate (i.e. non-invalid and non-abstentions)
  # are available in the statistics
  def get_answer_counts(table, q, where_hash)
    where_hash = where_hash.clone
    answ = {}
    if q.multi? # multiple choice questions ############################
      # find special no_answer field
      noansw_col = q.db_column.find_common_start+"noansw"
      if q.no_answer?
        where_hash[noansw_col] = 99
        answ[:abstentions] = count(table, where_hash)
        where_hash.delete(noansw_col)
      else
        answ[:abstentions] = 0
      end

      # find common answers
      q.boxes.each_with_index do |box, i|
        where_hash[q.db_column[i]] = i+1
        answ[(i+1)] = count(table, where_hash)
        c = box.any_text.strip_common_tex unless box.any_text.nil?
        answ[c] = answ[(i+1)] unless c.nil? || c.empty?
        where_hash.delete(q.db_column[i])
      end

      # in multi choice questions there is no “failed choice” (= -1)
      # However, questions that received no checkmark altogether will be
      # considered “without answer” (=0)
      q.db_column.each { |col| where_hash[col] = 0 }
      where_hash[noansw_col] = 0 if q.no_answer?
      answ[:invalid] = count(table, where_hash)
    else # single choice questions #####################################
      # find special values
      where_hash[q.db_column] = [-1, -2, 0]
      answ[:invalid] = count(table, where_hash)
      # don’t skip this, even if there cannot be any rows with that
      # value (i.e. the question doesn’t offer an «no answer» field)
      where_hash[q.db_column] = 99
      answ[:abstentions] = count(table, where_hash)
      # find normal values, store them with their index as well as their
      # name if available
      q.get_answers.each_with_index do |txt, i|
        where_hash[q.db_column] = i+1
        answ[(i+1)] = count(table, where_hash)
        t = txt.strip_common_tex unless txt.nil?
        answ[t] = answ[(i+1)] unless t.nil? || t.empty?
      end
    end
    answ
  end

  # converts a given hash into a where clause in the form of
  # key IN (value[,value[, …]])
  # If the clause could be generated without errors it is returned as
  # string, otherwise nil will be returned. It is assumed the query will
  # be a prepared statement, therefore you have to add the
  # *hash.values.flatten yourself to the execute function.
  def hash_to_where_clause(hash)
    return " 1 " if hash.empty?
    sql = hash.collect do |k, v|
      return nil unless report_valid_name?(k)
      amount_of_values = v.is_a?(Array) ? v.size : 1
      return nil if amount_of_values <= 0
      "#{k} IN (#{(["?"]*amount_of_values).join(",")})"
    end.join(" AND ")
    " #{sql} "
  end


  # checks query against errors and raises an error if they are found.
  # If there are any errors, then they are likely coding errors so they
  # should be fixed instead of ignored.
  def check_query(query, values)
    raise "\n\nQuery expects #{query.count("?")} values, but " + \
	  "#{values.flatten.count} are given.\nQuery: #{query}\n" + \
	  "Values: #{values.join(", ")}" \
	    if query.count("?") != values.flatten.count
  end

  # checks if the given name is valid and reports an error to STDERR if
  # it is not.
  def report_valid_name?(name)
    v = valid_name?(name)
    warn "Given name #{name} is invalid." unless v
    v
  end

  # returns true if the characters used for this name are valid. If an
  # array is given, it is checked recursively.
  def valid_name?(name)
    return name.all? {|x| valid_name?(x) } if name.is_a?(Array)
    name = name.to_s if name.is_a?(Symbol)
    return false if name.nil? || name.empty? || !name.is_a?(String)
    name[/[0-9A-Z_-]+/i] == name
  end

  # convenience translation method
  def t(name)
    I18n.translate(name.to_sym)
  end
end
