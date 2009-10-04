#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

module FunkyDBBits
  attr :dbh, :db_table
  
  # query fields, where-hash and additional clauses
  def query_single_table(f, h, t, additional = '')
    q = 'SELECT '
    q += f.to_a.join(', ')
    q += " FROM #{t}"
    q += ' WHERE ' + h.keys.join(' IN (?) AND ') + ' IN (?) ' +
      additional
    
    result = nil
    sth = @dbh.prepare(q)
    sth.execute(*h.values)
    sth.fetch_array { |r| result = r }
    if result.count == 1
      return result[0]
    else
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
    return query('COUNT(*)', h, additional)
  end

  # (where-clause-)hash h, question q
  def multi_q(h, q)
    anzahl = count_forms(h, " AND (#{q.db_column.join('+')} > 0)")
    answers = Hash.new
    q.db_column.each_index do |i|
      c = q.db_column[i]
      answers[q.boxes[i].text] = ( count_forms(h, " AND #{c} > " +
                                   '0').to_f * 100 / anzahl.to_f + 0.5
                                 ).to_i   
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
