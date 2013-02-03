# encoding: utf-8

# contains useful utilities to work with result data and transform it
# in into a more suitable way to display. The actual display routines
# are located in text/results/. I.e. database and TeX handling.
# The ResultTools class is shared globally, access it using
# ResultTools.instance

require "rubygems"
require "singleton"
require "dbi"

cdir = File.dirname(__FILE__)
require File.join(cdir, "../../config", "seee_config.rb")

class ResultTools
  # only allow one instance of this class
  include Singleton

  SCed = Seee::Config.external_database unless defined?(SCed)

  # adds the variables that are available when designing the form.
  # By default, only the form does have these variables, however since
  # questions may refer to them (e.g. \lect{} to get the lecturer’s
  # name) they should be included in the results as well.
  # Currently supported: course_prof, tutor
  def include_form_variables(klass)
    not_avail = []
    defined = {}
    if klass.is_a?(CourseProf)
      defined[:lect] = klass.prof.fullname
      defined[:lectLast] = klass.prof.lastname
    else
      not_avail += [:lect, :lectLast]
    end

    if klass.is_a?(Tutor)
      defined[:tutor] = klass.abbr_name
      defined[:myTutor] = klass.abbr_name
    else
      not_avail += [:tutor]
      not_avail += [:myTutor]
    end

    b = "\n"
    not_avail.each { |na| b << "\\def\\#{na}{\\variablesOutOfScopeErr}\n" }
    defined.each { |k,v| b << "\\def\\#{k}{#{v}}\n" }
    b
  end

  # returns a TeX-string for a small headline. Note that if two adjacent
  # headers are the same, the second header will be omitted. In other
  # words, categories with the same title are joined if they follow each
  # other. This is solved in TeX, not in Ruby/Rails.
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
    raise unless report_valid_name?(table)
    qry = case SCed[:dbi_handler].downcase
      when "sqlite3" then "SELECT name FROM sqlite_master WHERE type='table' AND name=?"
      # SQL standard as implemented by… nobody
      else "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ?"
    end
    sth = dbh.prepare(qry)
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
    return r["count"].to_i, r["avg"].to_f, r["stddev"].to_f
  end

  # Counts the amount of rows for the given hash. It is processed in the
  # form of key IN (value[,value[, …]]). Returns -1 if there were errors,
  # e.g. if one of the names contains invalid chars.
  # If table is an array the query is run for each of the tables
  # separately, i.e. the tables are not joined.
  # If a db column is given as 3rd argument, will group by that db
  # column and return multiple results. The format is a hash of
  # { value => count }
  def count(table, where_hash = {}, group = nil, skip_null = true)
    return -1 unless report_valid_name?(table)
    return table.uniq.collect {|t| count(t, where_hash, group) }.sum \
      if table.is_a?(Array)
    # Don’t report missing tables in test mode and don’t query them
    # even if they exist
    return 0 if ENV["RAILS_ENV"] == "test"
    unless table_exists?(table)
      warn "Given table `#{table}` does NOT exist."
      warn "Assuming this means there are no sheets for that table."
      warn "Returning 0 now."
      return 0
    end
    if group && group.is_a?(String)
      sql = "SELECT #{group} AS value, COUNT(*) AS count FROM #{table} WHERE"
    else
      sql = "SELECT COUNT(*) AS count FROM #{table} WHERE"
    end
    clause = hash_to_where_clause(where_hash)
    return -1 if clause.nil?
    sql << clause
    if group && group.is_a?(String)
      sql << " GROUP BY #{group} "
      r = {}
      custom_query(sql, where_hash.values, false).each do |row|
        next if skip_null && row["value"].nil?
        v = row["value"] =~ /^[0-9]+$/ ? row["value"].to_i : row["value"]
        r[v] = row["count"].to_i
      end
      return r
    else
      r = custom_query(sql, where_hash.values, true)
      return r["count"].to_i
    end
  end

  # May be used to group a given question by what was answered in
  # correlate_by. For example, if you want to see how the study group
  # attendance differs per major, you would it like this:
  # RT.correlate("some_table", "major", "study_group_attendance", {:barcode => 123})
  # Set combine_no_answers to true if you don’t want to differentiate
  # between “no checkmark” and “checked not specified”.
  def correlate(table, correlate_by, question, where_hash = {}, combine_no_answers = false)
    return -1 unless report_valid_name?(table)
    return -1 unless report_valid_name?(correlate_by)
    return -1 unless report_valid_name?(question)
    clause = hash_to_where_clause(where_hash)
    return -1 if clause.nil?
    qry = "SELECT DISTINCT #{correlate_by} FROM #{table} WHERE #{clause}"
    answ = custom_query(qry, where_hash.values).map { |row| row[correlate_by].to_i }
    if combine_no_answers && answ.include?(99)
      answ << 0 unless answ.include?(0)
      answ.delete(99)
    end

    results = {}
    answ.each do |a|
      if combine_no_answers && a == 0
        where_hash[correlate_by] = [0, 99]
        a = "not specified/no answer given"
      else
        where_hash[correlate_by] = a
      end
      results[a] = RT.count(table, where_hash, question)
    end
    # combine 0/99 for each value
    if combine_no_answers
      cpy = results
      cpy.each do |k,v|
        sum = (v[0] || 0 ) + (v[99] || 0 )
        next if sum == 0
        results[k]["not specified/no answer given"] = sum
        results[k].delete(99)
        results[k].delete(0)
      end
    end
    results
  end

  # Returns a histogram of the answers given for a specific table and
  # question. Table should be a string; the question a AbstractForm-
  # Question-Class. Give a single integer barcode to get the results for
  # one CourseProf or an array of integers for multiple ones. Set text_
  # only to false if you /also/ want to get the result count by box
  # index. Be careful when processing the output via TeX, as the text
  # may contain commas and there are no guard braces. If absolute_numbers
  # is false, then the percentage of each answer will be given. Otherwise
  # raw numbers are returned.
  def answer_histogram(table, question, barcode, text_only = true, absolute_numbers = false)
    raise "Invalid barcode" unless barcode.is_a?(Integer) || barcode.is_a?(Array)
    raise "Invalid question" unless question.is_a?(Question)
    raise "Invalid table" unless table_exists?(table)
    a = get_answer_counts(table, question, {:barcode => barcode})
    a.reject! { |k, v| k.is_a?(Integer) } if text_only
    unless absolute_numbers
      # sum up amount of all answers; ignore integer based ones so
      # answers aren’t counted multiple times
      sum = 0.0; a.each { |k, v| sum += k.is_a?(Integer) ? 0 : v }
      a = Hash[a.map {|k, v| [k, "#{v.to_f/sum*100.0}%"] }]
    end

    # removes guard braces inserted by get_anwer_counts
    r = Hash[a.map {|k, v| [k.is_a?(String) ? k[1..-2] : k, v] }]

    # sanity check
    exp = (question.boxes.size * (text_only ? 1 : 2)) + 2 # +invalid, abstentions
    if r.values.size != exp
      s = ["Histogram has different number of answers than expected."]
      s << "Expected: #{exp}   Present: #{r.values.size}"
      s << "Histogram keys: #{r.keys.join(", ")}"
      raise s.join("\n")
    end
    r
  end

  # runs a custom query against the result-database. Returns the all
  # results as an array of hashes and instantly finishes the statement.
  # Therefore you don’t want to use this if you gather large values. If
  # first_row is set to true, “LIMIT 1” will be added automatically and
  # the hash will be returned directely.
  def custom_query(query, values = [], first_row = false)
    raise "values parameter must be an array." unless values.is_a?(Array)
    query << " LIMIT 1" if first_row
    check_query(query, values)
    q = dbh.prepare(query)
    begin
      q.execute(*values.flatten)
      if first_row
        v = q.fetch_hash
      else
        v = []
        while h = q.fetch_hash do
          v << h
        end
      end
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

  # works the same as custom_query but never returns a result.
  def custom_query_no_result(query, values = [])
    raise "values parameter must be an array." unless values.is_a?(Array)
    check_query(query, values)
    q = dbh.prepare(query)
    begin
      q.execute(*values.flatten)
    rescue DBI::DatabaseError => e
      warn ""
      warn "Query:  #{query}"
      warn "Values: #{values.join(", ")}"
      raise "SQL-Error (Err-Code: #{e.err}; Err-Msg: #{e.errstr}; SQLSTATE: #{e.state}). Query was: #{query}"
    ensure
      q.finish
    end
  end

  # initializes a database connection. Since this class includes the
  # singleton mixin, only one connection will be opened per Ruby
  # instance.
  def initialize
    @tex = {}
  end

  # Closes the old connection, if it exists and opens a new one to the
  # one defined in Seee:Config.external_database. Use this if the
  # settings have changed, and you want to switch the database.
  def reconnect_to_database
    @dbh.disconnect if @dbh && @dbh.connected?
    @dbh = DBI.connect(
      "DBI:#{SCed[:dbi_handler]}:#{SCed[:database]}:#{SCed[:host]}",
      SCed[:username],
      SCed[:password])

    if @dbh.nil? || !@dbh.connected?
      debug "ERROR: Couldn’t open a results database connection."
      debug "Have a look at seee_config.rb to correct the settings."
      exit 1
    end
  end

  # returns the database handle. Use this insteady of directly accessing
  # @dbh, so connect on demand works.
  def dbh
    reconnect_to_database if @dbh.nil? || !@dbh.connected?
    @dbh
  end

  # evaluates a given question with the sheets matching special_where.
  # If the question type prints a comparison value it will be compared
  # against all sheets that can be found in compare_where. Note that
  # statistical values are only available to single choice questions
  # since they don’t make too much sense for multiple choice questions.
  # The answer count is calculated for the special_where for both
  # single and multiple choice questions. The answers for compare_where
  # are not counted until they are really required (send patches).
  # repeat_for_class expects the class to be given in which scope this
  # question is rendered. E.g. repeat_for=course; then give the course.
  # Usually passing «self» should be sufficient.
  def eval_question(table, q, special_where, compare_where, repeat_for_class, censor = false)
    b = if q.comment?
      eval_question_comment(table, q, special_where, repeat_for_class, censor)
    elsif q.multi?
      eval_question_multi(table, q, special_where, compare_where, repeat_for_class, censor)
    else
      eval_question_single(table, q, special_where, compare_where, repeat_for_class, censor)
    end
    (b + "\n\n")
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
        @tex[name] = "\n\nERROR: No TeX code found for results/" \
                      + "#{name.escape_for_tex}.tex.erb\n\n"
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
      b << IO.read(file) << "\n\n"
    end
    b
  end

  private ##############################################################

  # See eval_question; handles questions with user input text only.
  # Currently only supports one comment per class, i.e. one for the
  # course/lecture, one for each lecturer and one for each tutor. FIXME:
  # Needs to support an arbitrary amount of text questions per group.
  def eval_question_comment(table, q, special_where, repeat_for_class, censor)
    question_text = get_question_text(q, repeat_for_class)

    b = ''
    if repeat_for_class.respond_to?(:comment)
      comment = repeat_for_class.comment || ""
      [q.visualizer].flatten.each do |vis|
        b << ERB.new(load_tex("#{censor ? 'censor_' : ''}comment_#{vis}")).result(binding)
      end
    else
      b << "WARNING: Given class #{repeat_for_class.class} does not " \
            + "have a comment method. Cannot display comment."
    end

    b
  end

  # See eval_question; handles single choice questions only
  def eval_question_single(table, q, special_where, compare_where, repeat_for_class, censor)
    question_text = get_question_text(q, repeat_for_class)

    return ERB.new(load_tex("censor_stat_question")).result(binding) if censor

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
  def eval_question_multi(table, q, special_where, compare_where, repeat_for_class, censor)
    question_text = get_question_text(q, repeat_for_class)


    return ERB.new(load_tex("censor_stat_question")).result(binding) if censor

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

  # helper to generate the correct question text for a given question
  # and corresponding class. The class is currently used to derive
  # gender information. The language is derived from I18n.locale.
  def get_question_text(q, rfc)
    gender = rfc.respond_to?(:gender) ? rfc.gender : :both
    q.text(I18n.locale, gender).strip_common_tex
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
    # matches answer text to index. Required to also update the index
    # counts if handwritten answers match the predefined ones.
    text_to_ind = {}
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
      q.get_answers.each_with_index do |txt, i|
        where_hash[q.db_column[i]] = i+1
        answ[(i+1)] = count(table, where_hash)
        t = "{#{(txt || "#{i+1} of #{q.boxes.size}").strip_common_tex}}"
        answ[t] = answ[(i+1)]
        text_to_ind[t] = i+1
        where_hash.delete(q.db_column[i])
      end

      # in multi choice questions there is no “failed choice” (= -1)
      # However, questions that received no checkmark altogether will be
      # considered “without answer” (=0)
      q.db_column.each { |col| where_hash[col] = 0 }
      where_hash[noansw_col] = 0 if q.no_answer?
      answ[:invalid] = count(table, where_hash)
    else # single choice questions #####################################
      cc = count(table, where_hash, q.db_column)
      # find special values
      answ[:invalid] = cc.foz(-2) + cc.foz(-1) + cc.foz(0)
      # don’t skip this, even if there cannot be any rows with that
      # value (i.e. the question doesn’t offer an «no answer» field)
      answ[:abstentions] = cc.foz(99)
      # find normal values, store them with their index as well as their
      # name if available
      q.get_answers.each_with_index do |txt, i|
        answ[(i+1)] = cc.foz(i+1)
        t = "{#{(txt || "#{i+1} of #{q.boxes.size}").strip_common_tex}}"
        answ[t] = answ[(i+1)]
        text_to_ind[t] = i+1
      end
    end

    # handle additional answers written into the textbox
    if q.last_is_textbox?
      # load data and ignore empty text fields
      col = (q.multi? ? q.db_column.last : q.db_column) + "_text"
      cc = count(table, where_hash, col)
      cc.delete("")
      # make additional answers available via index as well
      ind = q.boxes.count
      all = 0

      cc.each do |v,c|
        # guard against commas
        v = "{#{v}}"
        # don’t simply overwrite the value. There might be cases where
        # the user wrote an answer although it is one of the earlier
        # checkboxes.
        if answ.has_key?(v)
          answ[text_to_ind[v]] += c
          answ[v] += c
        else
          ind += 1
          answ[ind] = c
          answ[v] = c
        end
        all += c
      end

      # correct the “last textbox” count from above
      answ[q.boxes.count] -= all
      # guard against commas (may cause problems when parsed in TeX)
      t = "{#{q.get_answers.last}}"
      answ[t] = answ[q.boxes.count] unless t.nil? || t.empty?
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
    unless v
      warn "Given name “#{name}” is invalid."
      begin; raise; rescue Exception => e
        warn e.backtrace
      end
    end
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

  def warn(text)
    if defined?(Rails) && Rails.logger
      Rails.logger.warn text
    else
      Kernel.warn text
    end
  end
end
