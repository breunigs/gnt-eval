# encoding: utf-8

DEBUG_MAILTO_ADDRESS = "SOME_DEBUG_MAIL_ADDRESS"

class Postoffice < ActionMailer::Base
  default :from     => Seee::Config.settings[:standard_mail_from],
          :reply_to => Seee::Config.settings[:standard_mail_from],
          :bcc      => Seee::Config.settings[:standard_mail_bcc]

  def ankuendigungsmail(course_id)
    c = Course.find(course_id)

    @course = c
    @anrede = prof_address(c)
    @sprache = {:de => 'Deutsch', :en => "Englisch"}[c.language]

    subject = "Evaluation Ihrer Veranstaltung '#{c.title}'"
    to = c.profs.collect{ |p| p.email }


    # debug = true ⇒ mail will only be sent to DEBUG_MAILTO_ADDRESS
    debug = true

    do_mail(to, subject, debug)
  end

  def erinnerungsmail(course_id)
    c = Course.find(course_id)

    @course = c
    @anrede = evaluator_address(c)

    subject = "Evaluation von '#{c.title}' am #{c.description}"
    to = c.fs_contact_addresses_array

    # debug = true ⇒ mail will only be sent to DEBUG_MAILTO_ADDRESS
    debug = true

    do_mail(to, subject, debug)
  end

  # verschickt die eval, will faculty_links ist array mit
  # faculty_links[faculty] =
  # 'http://mathphys.fsk.uni-heidelberg.de/~eval/.uieduie/Ich_bin_das_richtige_file.pdf'
  def evalverschickung(course_id, faculty_links)
    c = Course.find(course_id)

    @title = c.title
    @anrede = prof_address(c)
    @link = faculty_links[c.faculty] + '#nameddest=' + course_id.to_s

    subject = 'Ergebnisse der diessemestrigen Veranstaltungsumfrage'
    to = c.profs.collect{ |p| p.email }

    # debug = true ⇒ mail will only be sent to DEBUG_MAILTO_ADDRESS
    debug = true

    do_mail(to, subject, debug)
  end


  def single_evalverschickung(course_id, faculty_links, path = "")
    c = Course.find(course_id)

    @title = c.title
    @anrede = prof_address(c)
    @link = faculty_links[c.faculty]

    # guess the correct path
    if path.empty?
      filename = c.dir_friendly_title << '_' << c.semester.dirFriendlyName << '.pdf'
      path = File.join(Rails.root, '../tmp/results/singles/', filename)
    end

    if not File.exists?(path)
      raise "There is no file to send for course #{c.title} (#{c.id}). I have had a look here: '#{path}'"
    end

    attachments[File.basename(path)] = File.read(path)
    subject = 'Ergebnisse der diessemestrigen Veranstaltungsumfrage'
    to = c.profs.collect{ |p| p.email }

    # debug = true ⇒ mail will only be sent to DEBUG_MAILTO_ADDRESS
    debug = true

    do_mail(to, subject, debug)
  end

  private
  def do_mail(to, subject, debug = true)
    if debug
      mail(:to => DEBUG_MAILTO_ADDRESS, :cc => [], :bcc => [], :subject => subject)
    else
      mail(:to => to, :subject => subject)
    end
  end

  def prof_address(course)
    g = {:female => 'geehrte Frau', :male => 'geehrter Herr'}
    course.profs.map { |p|
      "sehr #{g[p.gender]} #{p.surname.strip}"
    }.join(', ').capitalize_first
  end

  def evaluator_address(course)
    course.evaluator.split(',').map{ |x| 'hallo ' + x.capitalize_first }.join(', ').capitalize_first
  end
end
