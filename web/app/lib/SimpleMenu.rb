#!/usr/bin/env ruby
# ncurses-ruby unfortunatly has no built-in support for menus
# i - unfortunately - have no particular interest in porting it.
# therefore this is a simple menu class, hence its name.
# it's build to show nothing but the menu - no implementation in windows
# no nothing, although it should not be difficult to write that.
#
# This piece of code was written by Oliver Thomas <oliver@lernresistenz.de>
# and resembles free software. It is distributed under the GNU GPL v2.
# You did probablay not receive a copy of that.
# GFOAD.

require 'ncurses'

class SimpleMenu
  attr_reader :items, :index, :lines, :cols

  def initialize(list)
    set_items(list)
    @index = 0
  end

  def items=(list)
    set_items(list)
    @index = 0
    @scr.clear
    print_menu
  end

  private

  def set_items(list)
    @items = list
    @items << Item.new("Exit") { exit }
  end
 
  def calculate_size
    @lines = ( Ncurses.LINES / @items.length).floor
    @cols = Ncurses.COLS
  end

  def add(what)
    `echo "#{what}" >> /home/amens/rbtail.log`
  end
  # displays menu at current position
  #
  def print_menu
    
    @scr.refresh
    @windows = Array.new
    calculate_size

    @items.each do |i|
      additional = ""
      cindex = @items.index(i)
      
      number = @windows.length || 0
      @windows[cindex] = Ncurses::WINDOW.new(@lines, @cols, number * @lines, 0)
      w = @windows[cindex]
      w.border(*([0]*8))
      
      # highlight if necessary
      #
      if(cindex == @index)
        w.attron(Ncurses::COLOR_PAIR(2))
        w.attron(Ncurses::A_STANDOUT)
        additional = " * "
      end
      
      out = additional + i.to_s + additional

      w.move(@lines/2,(@cols - out.length)/2)
      w.addstr(out)
    end

    @windows.each { |w| w.noutrefresh } 
  end


 
  # moving the selection around
  #
  def move_upwards
    if @index > 0
      @index = @index - 1
    end
    print_menu
  end

  def move_downwards
    if @index < (@items.length - 1)
      @index = @index + 1
    end
    print_menu
  end

  # executes the command
  #
  def execute
    @items[@index].exec
  end

  public

  # does the main stuff.
  # initialize ncurses and go into the main loop
  # and clean up afterwards
  #
  def do_menu
    begin
      @scr = Ncurses.initscr()
      Ncurses.cbreak()
      Ncurses.noecho()
      Ncurses.curs_set(0) # hide cursor
      @scr.intrflush(false)
      @scr.keypad(true)

      # there's no such thing as no-color-terminals
      Ncurses.start_color()
      Ncurses.init_pair(1, Ncurses::COLOR_WHITE, Ncurses::COLOR_BLACK) #std
      Ncurses.init_pair(2, Ncurses::COLOR_RED, Ncurses::COLOR_WHITE) #sel
      Ncurses.attron(Ncurses::COLOR_PAIR(1))
      Ncurses.attron(Ncurses::A_BOLD) 
      Ncurses.mousemask(Ncurses::BUTTON1_CLICKED, [])      

      print_menu
      # main loop
      #
      while(ch = Ncurses.getch)
        case ch
        when Ncurses::KEY_DOWN
          move_downwards

        when Ncurses::KEY_UP
          move_upwards
        
        when 10
          execute
        
        when Ncurses::KEY_MOUSE
          m = Ncurses::MEVENT.new
          Ncurses.getmouse(m)
          @index = (m.y / @lines)
          print_menu
          execute
        end

      end

    ensure
      stop
    end  
  end

  def stop
    Ncurses.echo()
    Ncurses.nocbreak()
    Ncurses.nl()
    Ncurses.endwin()
  end

end

class Item
  attr_accessor :caption, :command
  def initialize(caption, &cmd)
        @caption = caption
        @command = cmd
  end
  def to_s
    @caption
  end
  def exec
    @command.call
  end
end

