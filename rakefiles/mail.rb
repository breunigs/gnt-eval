# encoding: utf-8

namespace :mail do
  desc "send reminder mails to FSlers"
  task :reminder do
    s = Term.currently_active

    puts ("This will send reminder mails to _all_ fscontacts for courses " +
      "in term #{s.title}. I will now show you a list of the mails, " +
      "that I will send. After you have seen the list, you will still be " +
      "able to abort.\nPlease press Enter.").word_wrap
    $stdin.gets

    s.courses.each do |c|
      puts "For '#{c.title} I would send mail to #{c.fs_contact_addresses}"
    end

    puts "\n\nIf you really (and I mean REALLY) want to do this, type in 'Jasper ist doof':"
    check = $stdin.gets.chomp
    if check == 'Jasper ist doof'
      Postoffice.view_paths = ['web/app/views/']
      s.courses.each do |c|
        Postoffice.deliver_erinnerungsmail(c.id)
        puts "Delivered mail for #{c.title} to #{c.fs_contact_addresses}."
      end
    else
      puts "K, won't do anything."
    end
  end
end
