# -*- coding: utf-8 -*-
#/usr/bin/env ruby

# Wesentliche Fragen-Klasse mit einer Antwortmöglichkeit, rechnet gar
# nichts selbst sondern bekommt alles geschenkt. Nur das Zählen der
# Kästchen wird selbst vorgenommen.
class TeXSingleFrage
  
  # Frage will: Fragentext, Beschriftung links und rechts, abgegebene
  # Antworten im Fortmat: [0,1,3,9,0] (0*AW1, 1*AW2, ..., 0*AW5),
  # Anzahl abgegebener Antworten, arithmetisches Mittel,
  # arithmetisches Mittel über alle berücksichtigten Items,
  # Std-Abweichung, Std-Abweichung über alle berücksichtigten Items
  
  def initialize(frage, ltext, rtext, antworten, anzahl, mittel,
                 mittel_alle, sigma, sigma_alle)

    @antworten = antworten.map{ |x| x.to_f }
    @kaestchen = @antworten.count
    @frage = frage
    @ltext = ltext
    @rtext = rtext
    @mittel_alle = mittel_alle
    @sigma_alle = sigma_alle
    @anzahl = anzahl
    @mittel = mittel
    @sigma = sigma
    
    @width_mm = 45.0
    @width_u = 500 - (500 % @kaestchen)
    @unitlength = @width_mm/@width_u
    @bin = @width_u / @kaestchen
    @offset = (@width_u / @kaestchen) / 2
    @mittel_pos = (@bin*@mittel-@offset).abs
    @a_mittel_pos = (@bin*@mittel_alle - @offset).abs
    @var = (@bin*@sigma).abs
    @var_a = (@bin*@sigma_alle).abs
    @y_offset = 110
  end
  
  # Gibt den TeX-Code zur aktuellen Frage zurück
  
  def the_tex
    # Die Frage wird tatsächlich gemalt (!). Kruder TeX-Scheiß halt.
    b = ""
    b << "   \\parbox[t]{8.3cm}{\\raggedright #{@frage}}\n"
    b << "   \\hspace{0.3cm}\\rule[-1cm]{0mm}{1cm}\n"
    b << "   \\smash{\\raisebox{-1mm}{\\parbox{1.7cm}{\\flushright\\sffamily\\small #{@ltext}}}}\n"
    b << "   \\smash{\\raisebox{-0mm}{\\parbox[t]{#{@width_mm}mm}{\n"
    b << "      \\setlength{\\unitlength}{#{@unitlength}mm}   %%Beginn eines Histogramms"
    b << "      \\begin{picture}(#{@width_u},65)\n"
    b << "          \\put(0,#{35-@y_offset}){\\framebox(#{@width_u},100){}}\n"
    b << "          \\put(#{@mittel_pos}, #{20-@y_offset}){\\circle*{15}}\n"
    b << "          \\put(#{@mittel_pos}, #{20-@y_offset}){\\line(1,0){#{@var}}}\n"
    b << "          \\put(#{@mittel_pos}, #{20-@y_offset}){\\line(-1,0){#{@var}}}\n"
    b << "          \\put(#{@mittel_pos-@var},#{13-@y_offset}){\\line(0,1){14}}\n"
    b << "          \\put(#{@mittel_pos+@var},#{13-@y_offset}){\\line(0,1){14}}\n"

    # zweiten Balken nur ausgeben, wenn es überhaupt zweiten
    # Mittelwert resp. Std-Abweichung gibt
    if @mittel_alle != 0 || @sigma_alle != 0
      b << "          \\put(#{@a_mittel_pos},#{0-@y_offset}){\\circle{15}}\n"
      b << "          \\put(#{@a_mittel_pos},#{0-@y_offset}){\\line(1,0){#{@var_a}}}\n"
      b << "          \\put(#{@a_mittel_pos},#{0-@y_offset}){\\line(-1,0){#{@var_a}}}\n"
      b << "          \\put(#{@a_mittel_pos-@var_a},#{-7-@y_offset}){\\line(0,1){14}}\n"
      b << "          \\put(#{@a_mittel_pos+@var_a},#{-7-@y_offset}){\\line(0,1){14}}\n"
    end
    
    @antworten.each_index do |i|
      a = @antworten[i]
      rule_height = a*100 / @anzahl * @unitlength
      b << "          \\put(#{i*@bin},#{35-@y_offset}){\\rule{#{@width_mm/@kaestchen}mm}{#{rule_height}mm}}\n"
      b << "          \\put(#{i*@bin},#{35-@y_offset}){\\line(0,1){100}}\n" unless i == 0
    end
    
    b << "      \\end{picture}  %%Ende eines Histogramms\n"
    b << "   }}}\n"
    b << "   \\smash{\\raisebox{-1mm}{\\parbox{1.7cm}{\\flushleft\\sffamily\\small #{@rtext}}}}\n"
    b << "\n"
    return b
  end
end

# Mäßig intelligenter Wrapper, der für den Basiskurs geschrieben
# wurde. Kann Mittelwert und Std-Abweichung selbst ausrechnen, der
# Held. Recht gut für Test-Cases geeignet, könnte man meinen, weil man
# direkt Zahlen eingeben kann und er eine Frage ausspuckt.

class Frage < TeXSingleFrage

  # Was hat eine Frage alles?
  # Fragetext, Text rechts, Text links, Array antworten ([1,3,0,2,1]
  # bei sieben abgegebenen bögen), mittel_alle, sigma_alle
  def initialize(frage, ltext, rtext, antworten, mittel_alle = 0,
                 sigma_alle = 0)
    
    antworten.map! { |x| x.to_f }
    gesamt = antworten.inject(0) { |s,x| s+x }
  
    # Trial and Error in the ruby shell:
    mittel = (0..antworten.count-1).to_a.insert(0,0).inject { |w,x| w +
      (x+1)*antworten[x] } / gesamt
    
    sigma = Math.sqrt((0..antworten.count-1).to_a.insert(0,0). inject { |w,x| w +
      (antworten[x]/gesamt)*(x+1-mittel)**2 })
    
    super(frage, ltext, rtext, antworten, gesamt, mittel, mittel_alle,
          sigma, sigma_alle)
  end
end
