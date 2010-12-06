#!/usr/bin/env ruby

require '../web/config/boot'
require '../lib/ext_requirements.rb'

preheader = "--- !ruby/object:Section \nquestions: \n- !ruby/object:Question \n  db_column: tutnum\n  failchoice: -1\n  nochoice: \n  special_care: 1\n- !ruby/object:Question \n  boxes: \n  - !ruby/object:Box \n    choice: 1\n    text: Diplom\n  - !ruby/object:Box \n    choice: 2\n    text: Lehramt\n  - !ruby/object:Box \n    choice: 3\n    text: Bachelor\n  - !ruby/object:Box \n    choice: 4\n    text: Master\n  - !ruby/object:Box \n    choice: 5\n    text: Promotion\n  - !ruby/object:Box \n    choice: 6\n    text: Sonstiges\n  db_column: studienziel\n  failchoice: -1\n  nochoice: \n  special_care: 1\n- !ruby/object:Question \n  boxes: \n  - !ruby/object:Box \n    choice: 1\n    text: Mathematik\n  - !ruby/object:Box \n    choice: 2\n    text: Informatik\n  - !ruby/object:Box \n    choice: 3\n    text: Physik\n  - !ruby/object:Box \n    choice: 4\n    text: Sonstiges\n  db_column: hauptfach\n  failchoice: -1\n  nochoice: \n  qtext: Hauptfach\n  special_care: 1\n- !ruby/object:Question \n  boxes: \n  - !ruby/object:Box \n    choice: 1\n    text: 1\n  - !ruby/object:Box \n    choice: 2\n    text: 2\n  - !ruby/object:Box \n    choice: 3\n    text: 3\n  - !ruby/object:Box \n    choice: 4\n    text: 4\n  - !ruby/object:Box \n    choice: 5\n    text: 5\n  - !ruby/object:Box \n    choice: 6\n    text: 6\n  - !ruby/object:Box \n    choice: 7\n    text: 7\n  - !ruby/object:Box \n    choice: 8\n    text: 8\n  - !ruby/object:Box \n    choice: 9\n    text: 9\n  - !ruby/object:Box \n    choice: 10\n    text: 10\n  - !ruby/object:Box \n    choice: 11\n    text: 11\n  - !ruby/object:Box \n    choice: 12\n    text: 12\n  - !ruby/object:Box \n    choice: 13\n    text: 13\n  - !ruby/object:Box \n    choice: 14\n    text: 14\n  - !ruby/object:Box \n    choice: 15\n    text: 15\n  - !ruby/object:Box \n    choice: 16\n    text: \"> 15\"\n  db_column: semester\n  failchoice: -1\n  nochoice: \n  qtext: Fachsemester\n  special_care: 1\ntitle: Metakram\n"


def pretty_abstract_form abstract_form
  orig = $stdout
  sio = StringIO.new
  $stdout = sio
  pp abstract_form
  $stdout = orig
  
  # aber bitte ohne die ids und ohne @
  sio.string.gsub(/0x[^\s]*/,'').gsub(/@/,'')
end


filename = $ARGV[0]
db_table = $ARGV[1]

content = File.read(filename)
f = AbstractForm.new
f.db_table = db_table

f.pages.push(Page.new)
f.pages.first.sections.push(YAML::load(preheader))

content.each do |l|
  if l =~ /^\%/
    next
  elsif l =~ /\\q/
    x = l.split('}{')
    x.last.gsub!("}",'').gsub!("\n",'')

    multi = false
    if x[0] =~ /m\{/
      multi = true
    end
    
    x.first.gsub!(/^.*?\{/,'')
    boxes = []
    x.each_index do |i|
      if i > 0 && (i < (x.count.to_i - 1))
        boxes.push(Box.new(i.to_i, x[i]))
      end
    end
    f.pages.last.sections.last.questions.push(Question.new(boxes, x[0], -1, nil,'square', x.last))
  elsif l =~ /\\sect/
    title = l.match(/\\sect\{(.*?)\}/)[1]
    f.pages.last.sections.push(Section.new(title))
  elsif l =~ /\\np/
    f.pages.push(Page.new)
  elsif l =~ /\\kommentar/
    x = l.split('}{')
    x.last.gsub!("}",'').gsub!("\n",'')
    x.first.gsub!(/^.*?\{/,'')
    
    q = Question.new([], x[0])
    q.db_column = x[-3]
    q.donotuse = 1
    q.nochoice = nil

    f.pages.last.sections.last.questions.push(q)
  elsif l.empty? || l.gsub("\n",'').gsub(' ','').empty?
  else

  end
end

#puts pretty_abstract_form(f)
#puts f.to_yaml

g = Form.find($ARGV[2].to_i)
g.content = f.to_yaml
g.save
