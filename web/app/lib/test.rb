#!/usr/bin/env ruby

require 'SimpleMenu'

items = [ 
         MenuItem.new('Read smth') { $read = gets },
         MenuItem.new('say smth') { puts $read }
        ]
m = SimpleMenu.new(items)
m.do_menu
