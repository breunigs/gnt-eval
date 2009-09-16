class CourseProf < ActiveRecord::Base
  belongs_to :course
  belongs_to :prof
  
  # evals sth against some form \o/
  # for reasons of execution speed, provide some dbi-handle!
  def eval_against_form(form, dbh)
    this_eval = 'Physik SS 2009'
    form.questions.each do |q|
      col = q.db_column
      tab = form.db_table
      base_query = "SELECT STD(#{col}) AS sigma, AVG(#{col}) AS mittel, " +
                   "              COUNT(#{col}) AS anzahl " +
                   "          FROM #{tab}" +
                   "      WHERE #{col} != 0 AND eval = ? "


      mittel, sigma, anzahl = 0
      dbh.prepare(base_query + 'AND barcode IN (?)') do |sth|
        sth.execute(this_eval, barcode_with_checksum.to_i)
        sth.fetch { |r| sigma, mittel, anzahl = r }
      end

      mittel_alle, sigma_alle = 0
      dbh.prepare(base_query) do |sth|
        sth.execute(this_eval)
        sth.fetch { |r| sigma_alle, mittel_alle = r[0], r[1] }
      end
      
      # single values
      antworten = Array.new
      (1..q.size).each do |i|
        base_query = "SELECT COUNT(*) AS anzahl_i FROM #{tab} " +
                     "       WHERE eval = ? AND barcode IN (?) " +
                     "             AND #{col} = ?"
        dbh.prepare(base_query) do |sth|
          sth.execute(this_eval, barcode_with_checksum.to_i, i)
          sth.fetch_hash { |r| antworten.push(r['anzahl_i']) }
        end
      end
      p [mittel, sigma, anzahl, mittel_alle, sigma_alle, antworten]
    end
  end
  
  def barcode
    return "%07d" % id
  end

  def barcode_with_checksum
    long_number = barcode
    sum = 0
    (0..6).each do |i|
      weight = 1 + 2*((i+1)%2)
      sum += weight*long_number[i,1].to_i
    end
    long_number + ((sum.to_f/10).ceil*10-sum).to_s
  end
end
