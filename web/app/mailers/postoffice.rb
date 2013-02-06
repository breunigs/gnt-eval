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
    @sprache = I18n.t(c.language.to_sym, :raise => true)

    headers['X-GNT-Eval-Mail'] = __method__.to_s
    headers['X-GNT-Eval-Id'] = c.id.to_s

    to = c.profs.collect{ |p| p.email }

    # debug = true ⇒ mail will only be sent to DEBUG_MAILTO_ADDRESS
    debug = true

    do_mail(to, debug)
  end

  def erinnerungsmail(course_id)
    c = Course.find(course_id)

    @course = c
    @anrede = evaluator_address(c)

    headers['X-GNT-Eval-Mail'] = __method__.to_s
    headers['X-GNT-Eval-Id'] = c.id.to_s

    to = c.fs_contact_addresses_array

    # debug = true ⇒ mail will only be sent to DEBUG_MAILTO_ADDRESS
    debug = true

    do_mail(to, debug)
  end

  # verschickt die eval, will faculty_links ist array mit
  # faculty_links[faculty_id] =
  # 'http://mathphys.fsk.uni-heidelberg.de/~eval/.uieduie/Ich_bin_das_richtige_file.pdf'
  def evalverschickung(course_id, faculty_links)
    @course = c = Course.find(course_id)

    raise "faculty_links does not contain an entry for id=#{c.faculty.id}" if !faculty_links[c.faculty.id]

    headers['X-GNT-Eval-Mail'] = __method__.to_s
    headers['X-GNT-Eval-Id'] = c.id.to_s

    @title = c.title
    @anrede = prof_address(c)
    @link = faculty_links[c.faculty.id] + '#nameddest=' + course_id.to_s

    to = c.profs.collect{ |p| p.email }

    # debug = true ⇒ mail will only be sent to DEBUG_MAILTO_ADDRESS
    debug = true

    do_mail(to, debug)
  end


  def single_evalverschickung(course_id, faculty_links, path = "")
    @course = c = Course.find(course_id)

    headers['X-GNT-Eval-Mail'] = __method__.to_s
    headers['X-GNT-Eval-Id'] = c.id.to_s

    raise "faculty_links does not contain an entry for id=#{c.faculty.id}" if !faculty_links[c.faculty.id]

    unless c.all_unencrypted_ok?
      raise "Trying to send mail for #{c.title}, although not all profs agreed to publish/unenrypted mail."
    end

    @title = c.title
    @anrede = prof_address(c)
    @link = faculty_links[c.faculty.id]

    # guess the correct path
    if path.empty?
      filename = c.dir_friendly_title << '_' << c.term.dir_friendly_title << '.pdf'
      path = File.join(Rails.root, '../tmp/results/singles/', filename)
    end

    if not File.exists?(path)
      raise "There is no file to send for course #{c.title} (#{c.id}). I have had a look here: '#{path}'"
    end

    attachments[File.basename(path)] = File.read(path)
    to = c.profs.collect{ |p| p.email }

    # debug = true ⇒ mail will only be sent to DEBUG_MAILTO_ADDRESS
    debug = true

    do_mail(to, debug)
  end

  private
  def do_mail(to, debug = true)
    I18n.with_locale(@course.language.to_s) do
      subject = I18n.t("#{self.class.to_s.downcase}.#{caller[2][/`.*'/][1..-2]}.subject", :title => @course.title, :date => @course.description, :raise => true)

      if debug || to.compact.empty?
        headers['X-GNT-Eval-Debug'] = "yes"
        mail(:to => DEBUG_MAILTO_ADDRESS, :cc => [], :bcc => [], :subject => subject)
      else
        mail(:to => to.compact, :subject => subject)
      end
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
