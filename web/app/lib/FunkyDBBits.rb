#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

module FunkyDBBits
  attr :dbh, :db_table

  # Automatically connect to external database when required
  # and cache that connection
  require 'dbi'
  def self.dbh
    return @dbh if !@dbh.nil? && @dbh.connected?
    sced = Seee::Config.external_database
    @dbh = DBI.connect(
      "DBI:#{sced[:dbi_handler]}:#{sced[:database]}:#{sced[:host]}",
      sced[:username],
      sced[:password])
  end

  # convenience function so dbh can be accessed directly
  def dbh
    FunkyDBBits.dbh
  end

  # returns true if the given table exists, false otherwise
  def table_exists?(table)
    sth = dbh.prepare("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ?")
    sth.execute(table)
    sth.each { |r| return true }
    false
  end

  # query fields, where-hash and additional clauses
  # does caching, see uncached_query_single_table
  def query_single_table(f, h, t, additional = '', cache = true)

    # yes, this IS a global variable. and it is being used on purpose
    $cached_results ||= { }

    if cache == true
      $cached_results[[dbh, @db_table]] ||= { }
      $cached_results[[dbh, @db_table]][[f, h, t, additional]] ||=
        uncached_query_single_table(f, h, t, additional)
    else
      uncached_query_single_table(f, h, t, additional)
    end
  end

  # query fields, where-hash and additional clauses, all uncached
  def uncached_query_single_table(f, h, t, additional = '')
    q = 'SELECT '
    q << f.to_a.collect{|a| a.keep_valid_db_chars }.join(', ')
    q << " FROM #{t.keep_valid_db_chars}"

    c = []
    c << additional.sub(/^\s*AND/,'') unless additional.empty?

    unless h.empty?
      h.each do |k,v|
        # flatten the arrays because otherwise DBI will break for
        # Postgres for some reason
        amount_of_values = v.is_a?(Array) ? v.size : 1
        c << "#{k.keep_valid_db_chars} IN "
        c.last << "(#{(["?"]*amount_of_values).join(",")})"
      end
    end

    unless c.empty?
      q << " WHERE "
      q << c.join(" AND ")
    end

    sth = dbh.prepare(q)
    begin
      result = []
      sth.execute(*h.values.flatten)
      sth.each { |r| result << r }
    rescue DBI::DatabaseError => e
      puts "Query is: #{q}"
      print "Cond  is: "
      pp h
      puts "Table is: #{t}"
      print "Addition: "
      pp additional
      raise "SQL-Error (Err-Code: #{e.err}; Err-Msg: #{e.errstr}; SQLSTATE: #{e.state}). Query was: #{q}"
    end

    # try to return values directly, if only one row and value
    # have been selected
    return result if result.count != 1
    return result[0]  if result[0].count != 1 # not exactly one column
    r = result[0][0]
    if r.is_a?(String)
      r.to_i if r.to_i.to_s == r
      r.to_f if r.to_f.to_s == r
    end
    r
  end

  def query(f, h, additional = '')
    ts = @db_table.to_a
    # remove non existing tables
    ts = ts.find_all { |t| table_exists?(t) }
    res = ts.map{ |t| query_single_table(f, h, t, additional)}

    # at this very moment we just use queries over multiple tables at
    # the very beginning when counting all forms, so we can safely
    # (*cough*) do this:

    if res.count == 1
      return res[0]
    else
      if res.any?{ |r| not r.is_a?(Integer) }
        raise TypeError, "Shall use tables #{@db_table.join(', ')} and
  got results #{res.join(', ')}, which is like not good"
      else
        res.inject(0){ |sum,x| sum+x}
      end
    end
  end

  # returns count of stuff where i IN h[i] for each i + additional
  def count_forms(h, additional = '')
    begin
      res = query('COUNT(*)', h, additional)
    rescue => e
      # table that should be counted likely doesn't exist. Ignore
      # this and return 0 instead.
      return 0
    end
    if res.nil?
      p h
      p additional
      raise "something went nil"
    end
    return res.to_i
  end

  # gets the distinct values for the given field and where clause
  def get_distinct_values(column, h, additional = '')
    ts = @db_table.to_a
    arr = []
    ts.each do |t|
        arr << query_single_table('DISTINCT '+ column, h, t, additional)
    end
    arr.flatten.uniq
  end

  # (where-clause-)hash h, question q, language l
  def multi_q(h, q, l)
    anzahl = count_forms(h, " AND (#{q.db_column.join('+')} > 0)")
    answers = Hash.new
    if anzahl > 0
      q.db_column.sort.each_index do |i|
        c = q.db_column.sort[i]
        bxs = q.boxes.sort{ |x,y| x.choice <=> y.choice }
        answers[bxs[i].text[l]] = ( count_forms(h, " AND #{c} > " +
                                     '0').to_f * 100 / anzahl.to_f + 0.5
                                   ).to_i
      end
    end
    return answers
  end

  # h_particular: where-clause-hash für die EINE veranstaltung
  # h_general: where-clause-hash für die vergleichsveranstaltungen
  def single_q(h_particular, h_general, q)
    col = q.db_column
    sigma, mittel, anzahl = query(["STDDEV(#{col})", "AVG(#{col})",
                                   "COUNT(#{col})"], h_particular,
                                  "AND #{col} != 0")
    sigma_alle, mittel_alle = query(["STDDEV(#{col})", "AVG(#{col})"],
                                   h_general, "AND #{col} != 0")

    # single values
    antworten = Array.new
    (1..q.size).each do |i|
      antworten.push(count_forms(h_particular.merge({col => i})))
    end

    return [antworten, anzahl, mittel, mittel_alle, sigma, sigma_alle]
  end
end
