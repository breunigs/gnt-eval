require 'net/http'
require 'pp'
require 'rubygems'
require 'date'
require 'rexml/document'
require 'csv'
require File.dirname(__FILE__) + "/faster_csv"
require File.dirname(__FILE__) + "/../lib/result_tools.rb"
require File.dirname(__FILE__) + "/../lib/RandomUtils.rb"

RT = ResultTools.instance

TOPLEVEL="http://lsf.uni-heidelberg.de/qisserver/rds?state=wtree&search=1&category=veranstaltung.browse&topitem=lectures&subitem=lectureindex&breadcrumb=lectureindex"
BASELINK="http://lsf.uni-heidelberg.de/qisserver/rds?state=wtree&search=1&trex=step&P.vx=mittel&"
# URL used to search for stuff
SEARCH_LINK="https://lsf.uni-heidelberg.de/qisserver/rds?state=wsearchv&search=1&subdir=veranstaltung&personal.nachname=SURNAME&veranstaltung.dtxt=LECTURE&veranstaltung.semester=SEMESTER&_form=display"
SEARCH_


# Searches for a given lecture and prof, returns an array of possible
# lecture IDs.
def search(lecture, prof)
  s = SEARCH_LINK.gsub("LECTURE", lecture)
  s.gsub!("SURNAME", prof)

  y = Time.now.year
  summer = (Date.new(y, 3, 1)..Date.new(y, 8, 31)).include?(DateTime.now)
  # if we’re in winter term, but already celebrated new years…
  if !summer && (Date.new(y, 1, 1)..Date.new(y, 3, 1)).include?(DateTime.now)
    y -= 1
  end

  s.gsub!("SEMESTER", "#{y}#{summer?1:2}")

  req = Net::HTTP.get_response(URI.parse(URI.encode(s)))
  unless req.is_a?(Net::HTTPSuccess)
      puts "Sorry, couldn’t load LSF :("
      req.error!
  end
  dec = req.body.gsub(/\s+/, " ")
  dec = dec.scan(/state=wtree&amp;search=1&amp;trex=step&amp;(root[0-9][^&]+)[^"]+"\s+title="'([^']+)'/)
  dec.reject! { |d| d[0].scan("|").count <= depth }
  dec
end

def findSuitableURLs(link = TOPLEVEL)
    puts "Now checking #{link}" if @debug
    # find depth by counting the bar seperators
    depth = link.scan("|").count
    req = Net::HTTP.get_response(URI.parse(URI.encode(link)))
    unless req.is_a?(Net::HTTPSuccess)
        puts "Sorry, couldn't load LSF :("
        req.error!
    end
    dec = req.body.gsub(/\s+/, " ")
    dec = dec.scan(/state=wtree&amp;search=1&amp;trex=step&amp;(root[0-9][^&]+)[^"]+"\s+title="'([^']+)'/)
    dec.reject! { |d| d[0].scan("|").count <= depth }
    dec
end

def setSemAndRootFromURL(link)
  crap = link.scan(/root[0-9]([0-9]{5})=(?:[0-9]{5,}\|)+([0-9]{5,})/)
  @semester = crap[0][0].to_i
  @rootid = crap[0][1].to_i
  return @semester, @rootid
end


# semester, now auto-detected from input
# summer term 2009 == 20091
# winter term 2009/10 == 20092
# Example: semester=20092
#@semester=20101;

# URL to LSF Service
@hostUrl="http://lsf.uni-heidelberg.de/axis2/services/LSFService/"
# root tree IDs that identify the (sub-)tree of interest. You can find
# them in the html-LSF by having a look at the URL of root categories.
# Here's an example URL for maths in WS 2009/2010, with the number of
# interest highlighted:
# http://lsf.uni-heidelberg.de/qisserver/rds?state=wtree&search=1&
#     trex=step&root120092=18890|18842&P.vx=mittel
#                                ^^^^^

@debug = true

# Used to store requests that may occur more than once
@tempRooms = Array.new
@tempProfs = Array.new
# Used to determine if a specific branch or event has already been
# processed (so it can be skipped)
@tempEvents = Array.new
@tempTrees = Array.new

# Define data structures for events and professors.
# The time is directly parsed into a string
class Event < Struct.new(:id, :name, :times, :rooms, :profs, :type, :facul, :sws, :lang, :est_part, :detailTime); end
class Prof  < Struct.new(:id, :name, :mail, :tele, :first, :last, :title, :akad); end

# Overwrite hash function as otherwise stuff like array#uniq yiels
# wrong results
class Prof
  def hash; id end
end
class Event
  def hash; id end
end

class Prof
    def mailhref
        if mail.nil? || mail.empty?
            self.name
        else
            "<a href=\"mailto:#{self.mail}\">#{self.name}</a>"
        end
    end
end

class String
    # Make downcase support German umlauts
    def downcase
        self.tr 'A-ZÄÖÜ', 'a-zäöü'
    end

    # define some stoptypes that we do not want to include
    def isStopType?
        cmp = self.downcase
        case cmp
            when "übung", "praktikum", "kolloquium", "hauptseminar", "colloquium", "prüfung", "oberseminar":
                return true
        end
        false
    end

    # define some stopnames that we do not want to includes
    def isStopName?
        self =~ /^Werkstatt/i
    end

    # define some stoprooms that we cannot evaluate (e.g. Mannheim, Heilbronn)
    def isStopRoom?
        self =~ /^MA/
    end
end


# The following class extensions provide means to pre-select certain
# profs of events
class Prof
    def evalAlways?
        self.name == "von Hahn" || self.id == "12949" # Both "von Hahn"
    end
end

class Event
    def evalAlways?
        self.type == "Grundvorlesung" || self.type == "Kursvorlesung"
    end
end

class REXML::Element
  # get the text content of the first element with the given name.
  # ignores prefixes. Returns nil if no valid results can be
  # found.
  def content(name)
    begin
      self.get_elements("*[local-name()='#{name}']").first.text.strip
    rescue
      nil
    end
  end
end

# It's usually possible to use element.blub to get the child element
# named prefix:blub. However, since element.id is used by ruby, this is
# not possible and REXML doesn't seem to provide an alternative to this.
# So we need to get the prefix manually here.
def getPrefix(root = nil)
    return @prefix unless @prefix.nil?
    root ||= getXML('getUeberschr?ueid=' + @rootid.to_s + '&semester=' + @semester.to_s)
    #~ raise AssertionFailure.new("Couldn't get prefix") unless root.elements.size >= 1
    #~ pp root

    #~ @prefix=root.elements[1].elements[1].prefix
    @prefix=root.attributes.keys.find { |x| x != "ns" }
    raise AssertionFailure.new("Couldn't get prefix") if @prefix.nil? || @prefix.empty?
end

# Reads and parses the XML file from the @hostURL with the given
# parameters
def getXML(parameters)
    url = @hostUrl + parameters

    $cached_pages ||= {}
    $cache_hits ||= 0
    unless $cached_pages[url].nil?
      $cache_hits += 1
      return $cached_pages[url]
    end

    req = Net::HTTP.get_response(URI.parse(url))
    unless req.is_a?(Net::HTTPSuccess)
        puts "XML failure!"
        puts "URL: " + url
        req.error!
    end

    $cached_pages[url] = REXML::Document.new(req.body).root
    $cached_pages[url]
end

# Takes a "root id" as argument and recursively parses the LSF tree
# down to the event level
def getTree(id)
    puts if @debug
    puts "Loading Tree: #{id}" if @debug

    events = Array.new
    unless @tempTrees[id].nil?
      puts "Tree #{id} has already been covered, skipping"
      return []
    end
    @tempTrees[id] = true;

    root = getXML("getUeberschr?ueid=#{id}&semester=#{@semester}")
    getPrefix(root) if getPrefix.nil?
    # If the tree doesn't have any more branches…
    if root.elements.size >= 2
        root.elements.each do |subtree|
            next if subtree.elements[getPrefix + ':id'].nil?
            subid = Integer(subtree.elements[getPrefix + ':id'].text)
            puts "Reading Subtree: " + subid.to_s if @debug
            events = events + getTree(subid)
        end
    # …read the eventlist instead.
    else
        puts "Subtree " + id.to_s + " is not a tree." if @debug

        events += getEventList(id)
    end
    # Remove bogus events
    events.compact!
    events
end

# Finds all the events in a given branch/subtree id. Usually only the
# last branch contains events.
def getEventList(id)
    puts "Reading Event List " + id.to_s if @debug
    events = Array.new

    root = getXML('getVorl?ueid=' + id.to_s)
    root.elements.each do |event|
        puts "Parsing Event " + event.elements[getPrefix + ':vorID'].text if @debug
        events << getEvent(event.elements)
    end
    events
end

# Will read the Semesterwochenstunden, language for a given event
def getEventDetails(vorlID)
    root = getXML('getVerDet?vid=' + vorlID.to_s)
    root.elements.each do |data|
        sws = data.elements[getPrefix + ":sws"].text.to_i
        lang = data.elements[getPrefix + ":unterrsprache"].text.strip
        est_part = data.elements[getPrefix + ":erwartteilnehmer"].text.to_i
        return sws, lang, est_part == 0 ? "" : est_part.to_s
    end
    return 0, ""
end

# Will read all the details like professor, room, time and so on for a
# given event id. Returns nil if the event is/has a stoptype or stopname
def getEvent(eventdata)
    id = Integer(eventdata[getPrefix + ':vorID'].text)
    sws, lang, est_part = getEventDetails(id)

    return nil unless @tempEvents[id].nil?
    @tempEvents[id] = true

    type = eventdata[getPrefix + ':art'].text.strip
    return nil if type.isStopType?

    name = eventdata[getPrefix + ':name'].text.strip
    return nil if name.nil? || name.isStopName?

    facul = Integer(eventdata[getPrefix + ':eid'].text)

    times, rooms, profs, detailTime = getTimetable(id)
    # also skip all events that do not provide necessary information unless
    # there's SWS data available.
    return nil if (sws.nil? || sws == 0)  && (times.empty? || rooms.empty? || profs.empty?)

    Event.new(id, name, times, rooms, profs, type, facul, sws, lang, est_part, detailTime)
end

# Gets a room's name for the given id
def getRoom(id)
    return @tempRooms[id] unless @tempRooms[id].nil?
    puts "Reading Room: " + id.to_s if @debug
    root = getXML("getRaum?rgid=" + id.to_s)
    @tempRooms[id] = root.elements[1].text.strip || ""

    @tempRooms[id]
end

# Gets a list of professors associated with the given event id.
def getProfs(id)
    profs = Array.new
    root = getXML('getDozenten?vtid=' + id.to_s)

    root.elements.each do |p|
        profid = Integer(p.content("id"))
        name = p.content("name")
        # we want all the details
        profs << getProfDetails(profid, name)
    end

    profs.compact!
    profs
end

# completes professor information for the given ID and name. Name must
# be supplied externally because the current API does not support a
# query that contains all professor details.
def getProfDetails(id, name)
    return @tempProfs[id] unless @tempProfs[id].nil?

    puts "Reading Professor Details: #{id}" if @debug
    root = getXML("getDet?pid=#{id}")[0]
    first = root.content("vorname") || ""
    last = root.content("nachname")  || ""
    title = root.content("titel")  || ""
    akad = root.content(":akadgrad") || ""

    puts "Reading Professor Contact Details: " + id.to_s if @debug
    root = getXML('getKontakt?pid=' + id.to_s)[0]

    mail = root.content("email") || ""
    tele = root.content("telefon") || ""
    kid = Integer(root.content("kid"))

    @tempProfs[id] = Prof.new(kid, name.strip, mail.strip, tele.strip, first.strip, last.strip, title.strip, akad.strip)

    @tempProfs[id]
end

# small helper function that will check in-detail if a given XML-tag
# contains useful information
def isNil?(x, name)
    (x.nil? || x[getPrefix + name].nil? || x[getPrefix + name].text.nil?)
end

# gets all the dates an event has and finds according professors and
# rooms
def getTimetable(id)
    puts "Reading Timetable: #{id}" if @debug
    times = []
    rooms = []
    profs = []
    detailTime = { :ryth => [], :wday => [], :time => [], :date => [] }
    root = getXML('getTermine?vid=' + id.to_s)
    root.elements.each do |t|
        begin
            # Builds time string
            ryth = t.content("rhythmus")

            s = ""
            s << t.content("wochentag") << ", "
            s << ryth << ", " unless ryth == "wöch"

            if t.content("beginn") && t.content("ende")
                # for single dates only print one date
                s << t.content("beginn") + "–" unless ryth == "Einzel"
                s << t.content("ende")
            end
            # Only print dates if rhythm is not weekly
            if t.content("begindat") && t.content("endedat") && ryth != "wöch"
                s << ", "
                s << t.content("begindat") + "–" unless ryth == "Einzel"
                s << t.content("endedat")
            end
            # skip very short entries because they're probably just spaces/commas
            next if s.length < 7

            # detailed times
            detailTime[:ryth] << t.content("rhythmus") || ""
            detailTime[:wday] << t.content("wochentag") || ""
            detailTime[:time] << t.content("beginn") + " – " + (t.content("ende") || "?")
            detailTime[:date] << (t.content("begindat") || "?") + " – " + (t.content("endedat") || "?")

            # Get room
            room = Integer(t.content("terRaumID"))
            room = getRoom(room)
            next if room.nil? || room.empty? || room.isStopRoom?

            # Get prof
            prof = Integer(t.content("vtid"))
            prof = getProfs(prof)
            next if prof.nil? || prof.empty?

            rooms << room.gsub("Philos.-weg", "Philw.") \
                    .gsub("Alb.-Ueberle-Str", "A-Ueb-Str") \
                    .gsub("Mönchhofstr", "Mönchh") \
                    .gsub("Speyererstr", "Spey.") \
                    .gsub("Gesellschaft für Schwerionenforschung", "G. f. Ionenforsch.") \
                    .gsub("Besprechungsraum", "Bsprchngsrm") \
                    .gsub("Medienzentrum Raum", "R") \
                    .gsub("Seminarraum", "Semnarrm")
            times << s.gsub(/([0-9]):([0-9]{2})/, '\1<sup><small>\2</small></sup>') \
                    .gsub(/20([0-9]{2})/, '\1') \
                    .gsub("Einzel", 'Enzl')
            profs << prof
        rescue => e
            puts e.inspect
            puts e.backtrace
            next
        end
    end

   detailTime.each { |k,v| detailTime[k] = v.join(", ") }

    return times, rooms, profs, detailTime
end

# Helper function that will list the professors for each date comma
# separated. Dates are separated by newlines.
def listProfs(arr)
    array = arr.clone
    s=""
    array.each do |a|
      if a.empty?
        s << "<br>"
        next
      end

      s << a.collect { |e| e.mailhref }.join(", ") + "<br>"
    end
    s
end

def printAllmightyCSV(data)
  s = FasterCSV.generate({:headers => true}) do |csv|
    csv << ["id", "titel", "zeiten", "räume", "art", "fakultät-id", "erwartete Teilnehmer", "sws", "prof", "profmail",  "akad. grad", "anrede", "vorname", "nachname"]
    data.each do |d|
      profs = d.profs.flatten.uniq unless d.profs.nil?
      if profs.empty?
        csv << [d.id, d.name, d.times.join(", ").gsub(/<\/?[^>]*>/, ""), d.rooms.join(", "), d.type, d.facul, d.est_part, d.sws, "", "", "", "", "", ""]
        next
      end

      profs.each do |p|
        csv << [d.id, d.name, d.times.join(", ").gsub(/<\/?[^>]*>/, ""), d.rooms.join(", "), d.type, d.facul, d.est_part, d.sws, p.name, p.mail, p.akad, p.title, p.first, p.last]
      end
    end
  end
  s
end

def printZuvEvalCSV(data)
  s = FasterCSV.generate({:headers => true}) do |csv|
    csv << ["Funktion", "Anrede", "Titel", "Vorname", "Nachname", "E-Mail-Adresse", "Lehrveranstatlung: Name/Titel", "Lehrveranstaltungskennung laut LSF", "Lehrveranstaltungsort(e)", "Hier können Sie eintragen: 1) Von welcher studienorganisatorischen Einheit wird die Lehrveranstaltung angeboten (relevant bei Import / Export)? 2) Für welchen / welche Studiengänge wird die LV angeboten?", "Lehrveranstaltungsart", "erwartete Teilnehmer / benötigte Fragebögen", "weitere/Sekundär-Dozenten", "Sprache", "veranschlagte SWS", "Leistungspunkte", "Modulzugehörigkeit (zu welchem Modul gehört die LV? Ggf. Kürzel angeben) --> ggf. bei Studiengang mit eintragen?", "Rhythmus (Blockveranstaltung oder wöchentlich)", "Wochentag", "Zeit (Uhrzeit)", "Dauer (von bis)", "Präsenzveranstaltung oder Moodle-Kurs / E-Learning", "Pflichtveranstaltung für welchen Studiengang / welche Studiengänge?", "Wahlpflichtveranstaltung für welchen Studiengang / welche Studiengänge?", "Semester", "Studienjahr"]
    data.each do |d|
      profs = d.profs.flatten.uniq unless d.profs.nil?
      if profs.empty?
        csv << ["", "", "", "", "", "", d.name, d.id, d.rooms.join(", "), "", "", d.est_part, "KEINE", d.lang, d.sws == 0 ? "" : d.sws, "", "", d.detailTime[:ryth], d.detailTime[:wday], d.detailTime[:time], d.detailTime[:date], "", "", "", ""]
        next
      end

      profs.each do |p|
        csv << ["", "", p.title, p.first, p.last, p.mail, d.name, d.id, d.rooms.join(", "), "", "", d.est_part, profs.size == 1 ? "KEINE" : "insg. #{profs.size}, siehe anliegende Zeilen",  d.lang, d.sws == 0 ? "" : d.sws, "", "", d.detailTime[:ryth], d.detailTime[:wday], d.detailTime[:time], d.detailTime[:date], "", "", "", ""]
      end
    end
  end
  s
end


def printSWSSheet(data)
    s = ""
    data.each do |d|
        allprofs = Array.new
        allprofs << d.profs.flatten.uniq
        num = 0
        allprofs.each { |a| num += a.length }
        # SWS   SWS*Profs    Typ   Name    Profs
        s << d.sws.to_s + "\t"
        s << (d.sws.to_i*num).to_s + "\t"
        s << d.type + "\t"
        s << d.name + "\t"
        s << listProfs(allprofs).gsub(/<\/?[^>]*>/, "") + "\n"
    end
    s
end

def printYamlKummerKasten(data, faculty)
    s = "---\n"
    s << "events:\n"
    data.each do |d|
        next if d.profs.empty?
        case d.type
            when /vorlesung/i then type = "Vorlesung"
            when /seminar/i   then type = "Seminar"
            when /blockkurs/i then type = "Blockkurs"
            else next
        end

        profs = d.profs.flatten.uniq
        profs = profs.collect { |x| "{mail: " + x.mail + ", name: " + x.name + "}" }

        s << "  - type: " + type + "\n"
        s << "    name: \"" + d.name.gsub(/\([a-z\s,.]+\)$/i, "").gsub('"', "'") + "\"\n"
        s << "    profs: [" + profs.join(", ") + "]\n"
        s << "    sem:  " + @semester.to_s + "\n"
        s << "    fach: " + faculty.to_s + "\n"
    end

    s
end

def print_final_tex(data)
    data.sort! { |x,y| x.name <=> y.name }
    ERB.new(RT.load_tex("../lsf_parser_final")).result(binding)
end

def print_pre_tex(input)
  # sort be type, then by name
  input.sort! { |x,y| x.type+x.name <=> y.type+y.name }
  intro = 'Kreuze zu evaluierende Veranstaltungen. Streiche solche, die nicht evaluiert werden sollen. Achte besonders auf automatisch Gekreuzte. Erstellung: \the\day.\the\month.\the\year'
  margin = [0.5,0.5,1,-1]
  landscape = true
  head = ["?", "Name", "Typ", "Spr", "DozentIn"]
  align = "Y{0.5cm}Y{12cm}Y{4.5cm}Y{0.7cm}Y{8.2cm}"
  data = input.collect do |d|
    next if (d.times.empty? || d.rooms.empty? || d.profs.empty?)

    profs = d.profs.flatten.uniq
    if d.evalAlways? || profs.any? { |p| p.evalAlways? }
      box = '$\boxtimes$'
    else
      box = '$\Box$'
    end
    profs = profs.collect { |p| p.name }.uniq.join(", ")
    [box, d.name, d.type, d.lang[0..2], profs]
  end.compact

  ERB.new(RT.load_tex("../table")).result(binding)
end

def getFile(name = nil, delete = false)
    name = "lsf_parser_out.html" if name.nil?
    File.delete(name) if delete && File.exists?(name)
    return File.new(name, "a")
end
