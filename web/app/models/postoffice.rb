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
    from Seee::Config.settings[:standard_mail_from]
    bcc Seee::Config.settings[:standard_mail_bcc]
    subject "Evaluation Ihrer Veranstaltung '#{c.title}'"
    headers 'Reply-To' => Seee::Config.settings[:standard_mail_from]
    content_type 'text/plain'
    sent_on Time.now
    
    
    body[:course] = c
    body[:anrede] = profanrede(c)
  end

  def erinnerungsmail(course_id)
    c = Course.find(course_id)
    
    recipients c.fs_contact_addresses
    from Seee::Config.settings[:standard_mail_from]
    bcc Seee::Config.settings[:standard_mail_bcc]
    subject "Dein Glück, die Veranstaltung '#{c.title}' evaluieren zu dürfen"
    headers 'Reply-To' => Seee::Config.settings[:standard_mail_from]
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
    from Seee::Config.settings[:standard_mail_from]
    bcc Seee::Config.settings[:standard_mail_bcc]
    subject 'Ergebnisse der diessemestrigen Vorlesungsumfrage'
    headers 'Reply-To' => Seee::Config.settings[:standard_mail_from]
    content_type 'text/plain'
    sent_on Time.now
    
    body[:title] = c.title
    body[:anrede] = profanrede(c)
    body[:link] = faculty_links[c.faculty] + '#nameddest=' + course_id.to_s
  end
end
