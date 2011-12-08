#!/usr/bin/ruby

# Dieses Skript liest alle Veranstaltungen und Tutoren die sich im Online
# System der Physik befinden und speichert es in einer Textdatei/gibt es aus.
# Autor: Stefan Breunig
# Letzte Änderung: 2011-12-07

require 'rubygems'
require 'date'
require 'mechanize'
# Fix crappy charset detections. We can do this because we know what
# encoding the page is in.
WWW::Mechanize::Util::CODE_DIC[:SJIS] = "ISO-8859-1"
WWW::Mechanize::Util::CODE_DIC[:EUC] = "ISO-8859-1"


# CONFIG #########################
timeout       = 30
$writeTxt     = true
$separator    = ","
$writeConsole = true
$removeMes    = [/Dr\. /, /Priv\. Doz\. Dr\. /, /N\.N\./, /Prof\. Dr\. /]
##################################

# Liste von URLs die angeben wo man Daten aus dem LSF ziehen kann
module Url
    # Zur Auflistung der Vorlesungen
    Vorl  = 'http://uebungen.physik.uni-heidelberg.de/uebungen/liste.php?lang=en'
    # Datenblatt zu einer Vorlesungs-ID
    Event = 'http://uebungen.physik.uni-heidelberg.de/uebungen/liste.php?lang=en&vorl='
end

class Tree < Struct.new(:title, :dozent, :teilnehmer, :tutors); end

# Der Browser den alle Funktionen nutzen
$brows = WWW::Mechanize.new
$brows.read_timeout = $timeout

# Reinige Code etwas für einfachere Regexes
def cleanCode(c)
    c = c.gsub("&nbsp;", " ")
    c = c.gsub(/\s+/, " ")
end

# Findet alle online verfügbaren Vorlesungen und gibt ihre IDs als Array zurück
def loadVorl
    puts "Lade Vorlesungen"
    $brows.get(Url::Vorl) do |page|
        code = cleanCode(page.content)
        reg  = code.scan(/<a href=\'liste\.php\?vorl=([0-9]+)\' title=\'authentification needed\' >&lt;show group list/)
        ids  = Array.new
        reg.each { |r| ids.push(r[0]) }
        #puts pp(ids)
        return ids
    end
end

# Lädt Dozent, Vorlesungstitel und alle Tutoren zu gegebener Vorlesung herunter
def loadEvent(id)
    $brows.get(Url::Event + id.to_s) do |page|
        code = cleanCode(page.content)

        title  = code[/<h2><b>(.*) \(.*\)<\/b><\/h2>/, 1]
        dozent = code[/<span class=\'kleiner\'>Dozent: <\/span>(.*?) <span class=\'kleiner\'>/, 1]
        teiln = code[/<span class=\'rot\'>([0-9]+)<\/span> Participants/, 1]
        tuts = code.scan(/<li><a href=\'teilnehmer\.php\?gid=[0-9]+\'><b>(?:.*?)<\/b><\/a> \((.*?)\) <br>/)

        puts "Geladen: " + title

        title = "" if title.nil?
        dozent = "" if dozent.nil?

        tutors = Array.new
        tuts.each do |t|
            $removeMes.each { |r| t[0] = t[0].gsub(r, '').strip }
            tutors.push(t[0]) if !t[0].empty?
        end if !tuts.nil?

        return Tree.new(title.strip, dozent.strip, teiln.strip, tutors.uniq.sort)
    end
end

# returns given text in UTF-8 encoding
def utf8_enc(text, from = "ISO-8859-1")
  $ic ||= {}
  $ic[from] ||= Iconv.new('UTF-8', from)
  $ic[from].iconv(text + ' ')[0..-2]
end

# Speichert die Vorlesungen und Tutoren halbwegs hübsch in einer Textdatei
def printToFile(tree)
    filename = Date.today.strftime + " Tutoren Physik.txt"
    File.open(filename, 'w') do |f|
        tree.each do |v|
            f.puts '#################'
            f.puts utf8_enc(v.title)
            f.puts utf8_enc(v.dozent)
            f.puts "Teilnehmer: " + utf8_enc(v.teilnehmer)
            f.puts '#################'
            f.puts utf8_enc(v.tutors.join($separator))
            f.puts ''
            f.puts ''
            f.puts ''
        end
    end
end

# Lädt alles und macht alles/Einsprungspunkt
def loadAll()
    tree = Array.new
    loadVorl.each { |v| tree.push(loadEvent(v)) }

    puts pp(tree) if $writeConsole
    printToFile(tree) if $writeTxt

    return tree
end

loadAll
