#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

module FunkyDBBits
  attr :dbh, :db_table
  
  # returns count of stuff where i IN h[i] for each i + additional
  def count_forms(h, additional = '')
    b = 0
    q = "SELECT COUNT(*) AS anzahl FROM #{@db_table} WHERE " +
        "  #{fold_where_clause(h)} " + additional
    sth = @dbh.prepare(q)
    sth.execute(*h.values)
    sth.fetch_hash { |r| b = r['anzahl'] }
    return b
  end
  
  
  # (where-clause-)hash h, question q
  def multi_q(h, q)
    anzahl = count_forms(h, " AND (#{q.db_column.join('+')} > 0)")
    answers = Hash.new
    q.db_column.each_index do |i|
      c = q.db_column[i]
      answers[q.boxes[i].text] = ( count_forms(h, " AND #{c} >
                                   0").to_f * 100 / anzahl.to_f + 0.5
                                 ).to_i   
    end
    
    return answers
  end
  
  # h_particular: where-clause-hash für die EINE veranstaltung
  # h_general: where-clause-hash für die vergleichsveranstaltungen
  def single_q(h_particular, h_general, q)
    col = q.db_column
    b_q = "SELECT STD(#{col}) AS sigma, AVG(#{col}) AS mittel, " +
          "              COUNT(#{col}) AS anzahl " +
          "          FROM #{@db_table} " +
          "      WHERE #{col} != 0 AND "

    mittel, sigma, anzahl = 0
    
    @dbh.prepare(b_q + fold_where_clause(h_particular)) do |sth|
      sth.execute(*h_particular.values)
      sth.fetch { |r| sigma, mittel, anzahl = r }
    end
          
    mittel_alle, sigma_alle = 0
    @dbh.prepare(b_q + fold_where_clause(h_general)) do |sth|
      sth.execute(*h_general.values)
      sth.fetch { |r| sigma_alle, mittel_alle = r[0], r[1] }
    end
    
    # single values
    antworten = Array.new
    (1..q.size).each do |i|
      antworten.push(count_forms(h_particular.merge({col => i})))
    end

    return [antworten, anzahl, mittel, mittel_alle, sigma, sigma_alle]
  end
  
  # folding for use in 'i IN h[i] AND ...'
  def fold_where_clause(hash)
    hash.keys.join(' IN (?) AND ') + ' IN (?)'
  end

end
