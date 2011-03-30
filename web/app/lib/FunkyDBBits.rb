#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

module FunkyDBBits
  attr :dbh, :db_table

  # Automatically connect to external database when required
  # and cache that connection
  require 'dbi'
  def self.dbh
    return @dbh if !@dbh.nil? && @dbh.connected?
    @dbh = DBI.connect("DBI:#{Seee::Config.external_database[:dbi_handler]}:#{Seee::Config.external_database[:database]}",
             Seee::Config.external_database[:username],
             Seee::Config.external_database[:password])
  end

  # convenience function so dbh can be accessed directly
  def dbh
    FunkyDBBits.dbh
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
    q += f.to_a.join(', ')
    q += " FROM #{t}"

    if h.empty?
      if not additional.empty?
        additional = additional.sub(/^\s*AND/,'')
        q += ' WHERE ' + additional
      end
    else
      q += ' WHERE ' + h.keys.join(' IN (?) AND ') + ' IN (?) ' +
        additional
    end

    result = nil
    sth = dbh.prepare(q)
    begin
      sth.execute(*h.values)
      result = []
      sth.fetch_array { |r| result << r }
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
    if result.count == 1 # only one row has been found
      if result[0].count == 1
        result[0][0] # the result contains only one column
      else
        result[0] # the result contains at least two columns
      end
    else
      # if it contains more than one row simply return the
      # whole result
      return result
    end
  end

  def query(f, h, additional = '')
    ts = @db_table.to_a
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
    rescue DBI::ProgrammingError
      # table that should be counted likely doesn't exist. Ignore
      # this and return 0 instead.
      return 0
    end
    if res.nil?
      p h
      p additional
      raise "something went nil"
    end
    return res
  end

  # gets the distinct values for the given field and where clause
  def get_distinct_values(column, h, additional = '')
    ts = @db_table.to_a
    arr = []
    ts.each do |t|
        arr << query_single_table('DISTINCT `'+ column+'`', h, t, additional)
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
    sigma, mittel, anzahl = query(["STD(#{col})", "AVG(#{col})",
                                   "COUNT(#{col})"], h_particular,
                                  "AND #{col} != 0")
    sigma_alle, mittel_alle = query(["STD(#{col})", "AVG(#{col})"],
                                   h_general, "AND #{col} != 0")

    # single values
    antworten = Array.new
    (1..q.size).each do |i|
      antworten.push(count_forms(h_particular.merge({col => i})))
    end

    return [antworten, anzahl, mittel, mittel_alle, sigma, sigma_alle]
  end
end
