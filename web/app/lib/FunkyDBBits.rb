#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

module FunkyDBBits
  attr :dbh, :db_table

  # Automatically connect to external database when required
  # and cache that connection
  require 'dbi'
  def self.dbh
    return @dbh if !@dbh.nil? && @dbh.connected?
    sced = Seee::Config.external_database
    @dbh = DBI.connect(
      "DBI:#{sced[:dbi_handler]}:#{sced[:database]}:#{sced[:host]}",
      sced[:username],
      sced[:password])
  end

  # convenience function so dbh can be accessed directly
  def dbh
    FunkyDBBits.dbh
  end
end
