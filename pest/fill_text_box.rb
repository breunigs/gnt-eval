#!/usr/bin/env ruby
# encoding: utf-8

require 'pp'
require 'base64'

cdir = File.dirname(__FILE__)
require cdir + '/../web/config/environment.rb'
require cdir + '/helper.AbstractFormExtended.rb'

SCap = Seee::Config.application_paths

answ = {}

pdf_viewer_started = false
tmp_path = "#{temp_dir}/fill_text_box.jpg"

Term.currently_active.each do |term|
  term.forms.each do |source_form|
    puts "Proccessing #{source_form.name}"

    table = source_form.db_table
    unless RT.table_exists?(table)
      warn "#{term.title} | #{source_form.name}’s table #{table} " \
              + "does not exist. Skipping."
      warn ""
      next
    end

    source_form.questions.each do |quest|
      next unless quest.last_is_textbox?
      puts "  Question: #{quest.text}"
      # now we have a question which has a textbox.
      page = source_form.pages.find { |p| p.questions.include?(quest) }
      page_index = source_form.pages.index(page)
      puts "  on page: #{page_index}"

      col = quest.db_column
      txt_col = "#{col}_text"

      sql = "SELECT abstract_form, path FROM #{table} "
      sql << %(WHERE #{col} = ? AND (#{txt_col} = "" OR #{txt_col} IS NULL))
      rows = RT.custom_query(sql, [quest.boxes.count])


      answ[col] ||= {}

      rows.each do |r|
        form = Marshal.load(Base64.decode64(r["abstract_form"]))
        unless File.exist?(r["path"])
          warn "Missing file: #{r["path"]}. Skipping."
          next
        end

        box = form.get_question(col).boxes[quest.no_answer? ? -2 : -1]
        coords = "#{box.width.to_i+2*200}x#{box.height.to_i+2*100}"
        coords << "+#{box.x-200}+#{box.y-100}"
        cmd = "#{SCap[:convert]} \"#{r["path"]}[#{page_index}]\" "
        cmd << "-crop #{coords} \"#{tmp_path}\""
        # run command to generate excerpt and to display it to the user
        `#{SCap[:clear]} && #{cmd}`
        unless pdf_viewer_started
          fork { exec "#{SCap[:pdf_viewer]} \"#{tmp_path}\" 2>1 &> /dev/null" }
          pdf_viewer_started = true
        end
        # clear screen first
        print "\e[2J\e[f"
        puts "Path: #{r["path"]}"
        puts
        # print the most common values, but sort them alphabetically
        # to prevent them from jumping if they appear in a,b,a… form
        puts "Common values entered so far:"
        comm = answ[col].sort {|a,b| b[1] <=> a[1]}[0..10]
        comm.sort{|a,b| a[0] <=> b[0]}.each { |a| puts a[0] + "\n" }
        puts
        puts
        puts "What is written into the textbox in the center of the image?"
        print "> "
        value = gets.strip
        # increase count
        answ[col][value] ||= 0
        answ[col][value] += 1
        # store value to database
        sql = "UPDATE #{table} SET #{txt_col} = ? WHERE path = ?"
        RT.custom_query_no_result(sql, [value, r["path"]])
      end
    end
  end
end
