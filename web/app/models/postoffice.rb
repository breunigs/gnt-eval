# -*- coding: utf-8 -*-
class Postoffice < ActionMailer::Base

  def ankuendigungsmail(course_id)
    c = Course.find(course_id)

    recipients c.profs.collect{ |p| p.email }.join(', ')
    from 'evaluation@mathphys.fsk.uni-heidelberg.de'
    cc 'evaluation@mathphys.fsk.uni-heidelberg.de'
    subject "Evaluation Ihrer Veranstaltung '#{c.title}'"
    headers 'Reply-To' => 'evaluation@mathphys.fsk.uni-heidelberg.de'    
    content_type 'text/plain'
    sent_on Time.now
    
    anrede = c.profs.map{ |p| 'sehr ' + ['geehrte Frau',
                                         'geehrter Herr'][p.gender] + 
                              ' ' + p.surname }.join(', ').
             gsub(/^(\w)/) { $1.chars.capitalize }
    
    body[:course] = c
    body[:anrede] = anrede
  end

  def erinnerungsmail(course_id)
    c = Course.find(course_id)
    
    recipients c.fs_contact_addresses
    from 'evaluation@mathphys.fsk.uni-heidelberg.de'
    bcc 'eval@oth.dea.aleph0.de'
    subject "Dein Glück, die Vorlesung '#{c.title}' evaluieren zu dürfen"
    headers 'Reply-To' => 'evaluation@mathphys.fsk.uni-heidelberg.de'
    content_type 'text/plain'
    sent_on Time.now
    
    anrede = c.evaluator.split(',').map{ |x| 'hallo ' + x }.join(', ').
      gsub(/^(\w)/) { $1.chars.capitalize }
    body[:course] = c
    body[:anrede] = anrede
  end
end
