# -*- coding: utf-8 -*-
class Postoffice < ActionMailer::Base
  def profanrede(course)
    return course.profs.map{ |p| 'sehr ' + ['geehrte Frau',
                                         'geehrter Herr'][p.gender] + 
                              ' ' + p.surname.strip }.join(', ').
             gsub(/^(\w)/) { $1.chars.first.capitalize }
  end
  
  def ankuendigungsmail(course_id)
    c = Course.find(course_id)

    recipients c.profs.collect{ |p| p.email }.join(', ')
    from 'evaluation@mathphys.fsk.uni-heidelberg.de'
    cc 'evaluation@mathphys.fsk.uni-heidelberg.de'
    subject "Evaluation Ihrer Veranstaltung '#{c.title}'"
    headers 'Reply-To' => 'evaluation@mathphys.fsk.uni-heidelberg.de'    
    content_type 'text/plain'
    sent_on Time.now
    
    
    body[:course] = c
    body[:anrede] = profanrede(c)
  end

  def erinnerungsmail(course_id)
    c = Course.find(course_id)
    
    recipients c.fs_contact_addresses
    from 'evaluation@mathphys.fsk.uni-heidelberg.de'
    bcc 'eval@oth.dea.aleph0.de'
    subject "Dein Glück, die Veranstaltung '#{c.title}' evaluieren zu dürfen"
    headers 'Reply-To' => 'evaluation@mathphys.fsk.uni-heidelberg.de'
    content_type 'text/plain'
    sent_on Time.now
    
    anrede = c.evaluator.split(',').map{ |x| 'hallo ' + x }.join(', ').
      gsub(/^(\w)/) { $1.chars.first.capitalize }
    body[:course] = c
    body[:anrede] = anrede
  end
  
  # verschickt die eval, will faculty_links ist array mit
  # faculty_links[faculty] =
  # 'http://mathphys.fsk.uni-heidelberg.de/~eval/.uieduie/Ich_bin_das_richtige_file.pdf'
  def evalverschickung(course_id, faculty_links)
    c = Course.find(course_id)
    recipients c.profs.collect{ |p| p.email }.join(', ')
    from 'evaluation@mathphys.fsk.uni-heidelberg.de'
    bcc 'evaluation@mathphys.fsk.uni-heidelberg.de'
    subject 'Ergebnisse der diessemestrigen Vorlesungsumfrage'
    headers 'Reply-To' => 'evaluation@mathphys.fsk.uni-heidelberg.de'
    content_type 'text/plain'
    sent_on Time.now
    
    body[:title] = c.title
    body[:anrede] = profanrede(c)
    body[:link] = faculty_links[c.faculty] + '#nameddest=' + course_id.to_s
  end
end
