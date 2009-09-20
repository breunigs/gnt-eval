class CourseProf < ActiveRecord::Base
  belongs_to :course
  belongs_to :prof
  
  # eval and output
  def eval_against_form!(form, dbh)
    puts eval_against_form(form, dbh)
  end
  
  # evals sth against some form \o/
  # for reasons of execution speed, provide some dbi-handle!
  # returns a TeX-string
  def eval_against_form(form, dbh)
    b = ''
    tab = form.db_table  
    this_eval = ['Mathematik', 'Physik'][course.faculty] + ' ' + course.semester.title
    
    boegenanzahl = 0
    query = "SELECT COUNT(*) AS anzahl FROM #{tab} WHERE barcode = ?"
    sth = dbh.prepare(query)
    sth.execute(barcode_with_checksum.to_i)
    sth.fetch_hash{ |r| boegenanzahl = r['anzahl'] }
    
    b << "\\profkopf{#{prof.fullname}}{#{boegenanzahl}}\n\n"
    b << "\\fragenzurvorlesung\n\n"
    
    form.questions.each do |q|
      col = q.db_column
      
      # multi-q?
      if col.is_a?(Array)
        
        base_query = "SELECT COUNT(*) AS anzahl FROM #{tab}" +
                     "   WHERE eval = ? AND barcode = ? AND " + 
                     "      (#{col.join('+')}) > 0 "

        answers = Hash.new

        anzahl = 0
        sth = dbh.prepare(base_query)
        sth.execute(this_eval, barcode_with_checksum.to_i)
        sth.fetch_hash { |r| anzahl = r['anzahl'] }
        
        col.each_index do |i|
          c = col[i]
          sth = dbh.prepare(base_query + "AND #{c} > 0")
          sth.execute(this_eval, barcode_with_checksum.to_i)
          sth.fetch_hash do |r|
            answers[q.boxes[i].text] = (r['anzahl'].to_f * 100/anzahl.to_f + 0.5).to_i
          end
        end
      
        t = TeXMultiQuestion.new(q.text, answers)
        b << t.to_tex
        
      # single-q
      else
        base_query = "SELECT STD(#{col}) AS sigma, AVG(#{col}) AS mittel, " +
                     "              COUNT(#{col}) AS anzahl " +
                     "          FROM #{tab}" +
                     "      WHERE #{col} != 0 AND eval = ? "

        mittel, sigma, anzahl = 0
        dbh.prepare(base_query + 'AND barcode = ?') do |sth|
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
                       "       WHERE eval = ? AND barcode = ? " +
                       "             AND #{col} = ?"
          dbh.prepare(base_query) do |sth|
            sth.execute(this_eval, barcode_with_checksum.to_i, i)
            sth.fetch_hash { |r| antworten.push(r['anzahl_i']) }
          end
        end

        # p [mittel, sigma, anzahl, mittel_alle, sigma_alle, antworten]
        t = TeXSingleQuestion.new(q.qtext, q.ltext, q.rtext, antworten,
                                  anzahl, mittel, mittel_alle, sigma,
                                  sigma_alle)

        b << t.to_tex
      end
    end
    return b
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
