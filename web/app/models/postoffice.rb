# -*- coding: utf-8 -*-

require File.dirname(__FILE__) + '/../lib/RandomUtils.rb'

class Postoffice < ActionMailer::Base
  def profanrede(course)
    return course.profs.map{ |p| 'sehr ' + {:female => 'geehrte Frau',
        :male => 'geehrter Herr'}[p.gender] + 
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
    body[:sprache] = {:de => 'Deutsch', :en => "Englisch"}[c.language]
  end

  def erinnerungsmail(course_id)
    c = Course.find(course_id)
    
    recipients c.fs_contact_addresses
    from Seee::Config.settings[:standard_mail_from]
    bcc Seee::Config.settings[:standard_mail_bcc]
    subject "Evaluation von '#{c.title}' am #{c.description}"
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
    subject 'Ergebnisse der diessemestrigen Veranstaltungsumfrage'
    headers 'Reply-To' => Seee::Config.settings[:standard_mail_from]
    content_type 'text/plain'
    sent_on Time.now
    
    body[:title] = c.title
    body[:anrede] = profanrede(c)
    body[:link] = faculty_links[c.faculty] + '#nameddest=' + course_id.to_s
  end

  
  def single_evalverschickung(course_id, faculty_links, path = "")
    c = Course.find(course_id)
    recipients c.profs.collect{ |p| p.email }.join(', ')
    
    from Seee::Config.settings[:standard_mail_from]
    bcc Seee::Config.settings[:standard_mail_bcc]
    subject 'Ergebnisse der diessemestrigen Veranstaltungsumfrage'
    headers 'Reply-To' => Seee::Config.settings[:standard_mail_from]
    content_type 'text/plain'
    sent_on Time.now
    
    body[:title] = c.title
    body[:anrede] = profanrede(c)
    body[:link] = faculty_links[c.faculty]

    # guess the correct path
    if path.empty?
      filename = c.title.strip.gsub(/\s+/, '_') << '_' << c.semester.dirFriendlyName << '.pdf'
      path = File.join(Rails.root, '../tmp/results/singles/', filename)
    end

    if not File.exists?(path)
      raise "There is no file to send for course #{c.title}. I have had a look here: '#{path}'"
    end

    attachment :content_type => 'application/pdf', :filename => File.basename(path), :body => File.read(path)
  end
end
