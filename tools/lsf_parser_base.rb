# encoding: utf-8

# Boot Rails iff the tool is called stand alone. If some of the Rails
# stack is already loaded, assume that all dependencies are fulfilled.
require "#{File.dirname(__FILE__)}/../web/config/environment" unless defined?(GNT_ROOT)
require 'net/http'
require 'rexml/document'

RT = ResultTools.instance unless defined?(RT)

# About the term ID:
# summer term 2009 == 20091
# winter term 2009/10 == 20092
# Example: term=20092

# About root IDs:
# root tree IDs that identify the (sub-)tree of interest. You can find
# them in the html-LSF by having a look at the URL of root categories.
# Here's an example URL for maths in WS 2009/2010, with the number of
# interest highlighted:
# http://lsf.uni-heidelberg.de/qisserver/rds?state=wtree&search=1&
#     trex=step&root120092=18890|18842&P.vx=mittel
#                                ^^^^^

class LSF
  # URL to LSF Service
  HOST_URL="http://lsf.uni-heidelberg.de/axis2/services/LSFService/"

  # Points to the HTML serving component of the LSF, as the LSFService
  # doesn’t seem to include a search function. Replace SURNAME, LECTURE
  # and TERM with the desired values to get a valid search URL that can
  # be processed further.
  SEARCH_URL="http://lsf.uni-heidelberg.de/qisserver/rds?state=wsearchv&search=1&subdir=veranstaltung&personal.nachname=SURNAME&veranstaltung.dtxt=LECTURE&veranstaltung.semester=TERM&_form=display"

  # points to the root of the HTTP tree
  TOPLEVEL="http://lsf.uni-heidelberg.de/qisserver/rds?state=wtree&search=1&category=veranstaltung.browse&topitem=lectures&subitem=lectureindex&breadcrumb=lectureindex"

  # When finding suitable HTML tree URLs, this will be prepended in
  # order to get a full and correct address.
  BASELINK="http://lsf.uni-heidelberg.de/qisserver/rds?state=wtree&search=1&trex=step&P.vx=mittel&"

  # Used to look for the faculty’s name
  FACULTY="http://lsf.uni-heidelberg.de/qisserver/rds?state=verpublish&status=init&vmfile=no&moduleCall=webInfo&publishConfFile=webInfoEinrichtung&publishSubDir=einrichtung&einrichtung.eid="

  @@cache_http = {}
  @@cache_xml = {}
  @@cache_profs = {}
  @@cache_room = {}
  @@cache_timetable = {}

  @@level = 0

  @@debug = true

  # “net” methods ######################################################

  # Loads the given URL and returns the resulting body text. Eliminates
  # almost all spaces (esp. newlines). Raises if the request fails. Use
  # this for normal URLs that do not need to be interpreted by the API.
  def self.load_url(url)
    return @@cache_http[url] if @@cache_http[url]

    #if File.exists?("/tmp/seee/"+url.gsub(/[^a-z0-9\-_]/, ""))
    #   @@cache_http[url] = `cat #{"/tmp/seee/"+url.gsub(/[^a-z0-9\-_]/, "")}`
    #   return @@cache_http[url]
    #end
    #puts "actually loading #{url}"
    req = Net::HTTP.get_response(URI.parse(URI.encode(url)))
    unless req.is_a?(Net::HTTPSuccess)
      warn "Sorry, couldn’t load LSF :("
      warn "URL: #{url}"
      req.error!
    end
    # Net::HTTP always returns ASCII-8BIT encoding although the webpage
    # is delivered in UTF-8. Try to read encoding from the headers and
    # use that.
    enc = req.get_fields("content-type").join.match(/charset=([a-z0-9-]+)/i)
    @@cache_http[url] = req.body.force_encoding(enc[1]).gsub(/\s+/, " ")
    #File.open("/tmp/seee/"+url.gsub(/[^a-z0-9\-_]/, ""), 'w') {|f| f.write(@@cache_http[url]) }

    @@cache_http[url]
  end

  # Reads and parses the XML file as returned by LSF Service. Returns an
  # XML document
  def self.load_xml(parameters)
    url = HOST_URL + parameters
    return @@cache_xml[url] if @@cache_xml[url]
    @@cache_xml[url] = REXML::Document.new(LSF.load_url(url)).root
    @@cache_xml[url]
  end

  # Includes all required files in order to connect to Seee/Rails
  def self.connect_rails
    require "#{GNT_ROOT}/web/config/environment"
  end

  # Searches for a given lecture and prof, returns an array of possible
  # lectures. Automatically rejects all courses that have a stop type or
  # name or have invalid or incomplete data.
  def self.search(lecture, prof)
    s = SEARCH_URL.gsub("LECTURE", lecture)
    s.gsub!("SURNAME", prof)
    s.gsub!("TERM", LSF.guess_term)
    lect_ids = load_url(s).scan(/publishid=([0-9]+)&/).flatten
    lects = lect_ids.map { |l| [*LSF.get_lecture(l)] }
    # remove all lectures whose skip attribute is set to true
    lects.reject! { |l| l[1] }
    lects.map { |l| l[0] }
  end

  def self.facul_id_to_name(id)
    load_url(FACULTY + id.to_s).match(/<h2>(.*?)<\/h2>/)[0].strip_html
  end

  # LSF Service methods ################################################


  # Loads a lecture and all details if given an ID. Returns lecture
  # first, and a boolean if the lecture should be ignored (i.e. stop
  # type occured type occured or incomplete data). Does not include
  # faculty.
  def self.get_lecture(id)
    return nil, true if id.to_s.empty? || id.to_s == "0"
    LSF.debug("Reading lecture: #{id}")
    @@level += 1
    l = LSF.get_lecture_details(id)
    l.merge!(LSF.get_timetable(id))

    skip = !l[:type].nil? && l[:type].is_stop_type?
    skip = skip || l[:name].nil? || l[:name].is_stop_name?
    # skip lectures that neither has time/rooms/prof nor SWS information
    no_sws = l[:sws].nil? || l[:sws] == 0
    no_trp = l[:times].empty? || l[:rooms].empty? || l[:profs].empty?
    skip = skip || (no_sws && no_trp)
    @@level -= 1
    return LSFLecture.new(l), skip
  end

  # Will read available details for the given lecture id. Returns Hash.
  def self.get_lecture_details(id)
    LSF.debug("Reading lecture details: #{id}")
    root = LSF.load_xml("getVerDet?vid=#{id}").first
    return {} if root.nil?
    {
      :id       => id,
      :sws      => root.content("sws").to_i,
      :lang     => root.content("unterrsprache"),
      :type     => root.content("verart"),
      :link     => root.content("hyperlink"),
      :note     => root.content("bemerkung"),
      :name     => root.content("dtxt"),
      :est_part => root.content("erwartteilnehmer")
    }
  end

  # Finds all the events in a given branch/subtree id. Only the last
  # branch contains events.
  def self.get_lectures(id)
    LSF.debug "Reading Lecture List #{id}"
    @@level += 1
    root = LSF.load_xml("getVorl?ueid=#{id}")
    l = root.elements.map do |ldat|
      lect, skip = LSF.get_lecture(ldat.content("vorID"))
      lect.facul = ldat.content("eid")
      lect.facul_name = LSF.facul_id_to_name(lect.facul)
      skip ? nil : lect
    end.compact
    @@level -= 1
    l
  end

  # completes professor information for the given ID and name. Name must
  # be supplied externally because the current API does not support a
  # query that contains all professor details.
  def self.get_prof(id)
    return @@cache_profs[id] unless @@cache_profs[id].nil?
    p = LSFProf.new

    LSF.debug "Reading Professor Details: #{id}"
    root = LSF.load_xml("getDet?pid=#{id}")[0]
    p.first = root.content("vorname")
    p.last = root.content("nachname")
    p.title = root.content("titel")
    p.akad = root.content("akadgrad")

    LSF.debug "Reading Professor Contact Details: #{id}"
    root = LSF.load_xml("getKontakt?pid=#{id}")[0]
    p.mail = root.content("email")
    p.tele = root.content("telefon")
    p.id = Integer(root.content("kid"))

    @@cache_profs[id] = p
    p
  end

  # Gets a list of professors associated with the given prof group id.
  # It depends on the lecture as well as the time, as a single lecture
  # may be given by multiple profs.
  def self.get_profs(id)
    root = LSF.load_xml('getDozenten?vtid=' + id.to_s)
    profs = root.elements.map { |p| LSF.get_prof(p.content("id")) }
    profs.compact
  end

  # Gets a room’s name for the given room id
  def self.get_room(id)
    return "" unless id.to_i > 0
    return @@cache_room[id] if @@cache_room[id]
    LSF.debug "Reading Room: #{id}"
    @@cache_room[id] = LSF.load_xml("getRaum?rgid=#{id}").content("return")
    @@cache_room[id]
  end

  # gets all the dates an event has and finds according professors and
  # rooms. Expects a lecture id.
  def self.get_timetable(id)
    return @@cache_timetable[id] if @@cache_timetable[id]
    LSF.debug "Reading Timetable: #{id}"
    @@level += 1
    times, rooms, profs = [], [], []
    detail_time = { :ryth => [], :wday => [], :time => [], :date => [] }
    root = LSF.load_xml("getTermine?vid=#{id}")
    root.elements.each do |t|
      # Builds time string
      ryth = t.content("rhythmus") || ""

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
      detail_time[:ryth] << ryth
      detail_time[:wday] << t.content("wochentag", "")
      detail_time[:time] << "#{t.content("beginn", "?")} – #{t.content("ende", "?")}"
      detail_time[:date] << "#{t.content("begindat", "?")} – #{t.content("endedat", "?")}"

      # Get room
      room = LSF.get_room(t.content("terRaumID"))
      next if room.nil? || room.empty? || room.is_stop_room?

      # Get prof. Although the variable is singular, a lecture may be
      # given by multiple profs at the same time.
      prof = LSF.get_profs(t.content("vtid"))
      next if prof.nil? || prof.empty?

      rooms << room.shorten_room
      times << s.htmlify_times
      profs << prof
    end

    detail_time.each { |k,v| detail_time[k] = v.join(", ") }

    @@cache_timetable[id] = {
      :times => times,
      :rooms => rooms,
      :profs => profs,
      :detail_time => detail_time
    }
    @@level -= 1
    @@cache_timetable[id]
  end


  # Takes a "root id" as argument and recursively parses the LSF tree
  # down to the event level
  def self.get_tree(id, processed_trees = [])
    LSF.debug "Loading Tree: #{id}"

    if processed_trees.empty?
      @@level = 1
    else
      @@level += 1
    end

    if processed_trees.include?(id)
      puts "Tree #{id} has already been covered, skipping"
      return []
    end
    processed_trees << id

    root = LSF.load_xml("getUeberschr?ueid=#{id}&semester=#{LSF.term}")
    lectures = []
    # If the branch has sub branches, then read them
    if root.elements.size >= 1
      root.elements.each do |subtree|
        subid = subtree.content("id")
        next if subid.nil?
        LSF.debug "Reading Subtree: #{subid}"
        lectures += LSF.get_tree(subid, processed_trees)
      end
    # Otherwise get list of lectures in that leaf.
    else
      LSF.debug "Found leaf at #{id}. Reading lectures."
      lectures += LSF.get_lectures(id)
    end
    # Remove bogus lectures
    lectures.compact!
    lectures
  end

  # helper methods #####################################################

  # returns the term as either set manually or guessed.
  def self.term
    @@term || LSF.guess_term
  end

  # returns the stored root ID which may be passed to get_tree. Root ID
  # is currently not used internally.
  def self.rootid
    @@rootid
  end

  # extracts term and root id from the given URL and stores it as class
  # variables. These IDs are required to bootstrap the recursive
  # tree-walk. Also returns them as term, rootid.
  def self.set_term_and_root(link)
    ids = link.scan(/root[0-9]([0-9]{5})=(?:[0-9]{5,}\|)+([0-9]{5,})/)
    @@term = ids[0][0].to_i
    @@rootid = ids[0][1].to_i
    return @@term, @@rootid
  end

  # Tries to guess the current term by looking at the date. Assumes
  # summer term is from March, 1st  to August, 31th.
  def self.guess_term
    y = Time.now.year
    # terms overlap on March, 1st. This shouldn’t be a problem though,
    # since we only need the latter to correct the year value and not
    # to determine if it’s summer/winter.
    term_summer = Date.new(y, 3, 1)..Date.new(y, 8, 31)
    term_winter_newyear = Date.new(y, 1, 1)..Date.new(y, 3, 1)

    summer = term_summer.include?(Date.today)
    # if we’re in winter term, but already celebrated new years…
    y -= 1 if !summer && term_winter_newyear.include?(DateTime.now)
    "#{y}#{summer ? 1 : 2}"
  end

  # Helper function that will list the professors for each date comma
  # separated. Dates are separated by HTML-newlines (i.e. <br>). Profs
  # are hyperlinked with their mail address.
  def self.list_profs_html(arr)
    arr.map { |a|  a.map { |e| e.mailhref }.join(", ") + "<br>" }.join
  end

  # Finds URLs in the given (HTML) LSF URL that can be used to further
  # travel down the tree. If no link is given, starts from the top
  # level. Returns results in the form of [{ :url => "", :title => "" }]
  def self.find_suitable_urls(link = TOPLEVEL)
    LSF.debug "Now checking #{link}"

    dec = LSF.load_url(link)
    dec = dec.scan(/state=wtree&amp;search=1&amp;trex=step&amp;(root[0-9][^&]+)[^"]+"\s+title="'([^']+)'/)
    dec.map! { |d| { :url => BASELINK + d[0], :title => d[1] } }
    # find depth by counting the bar seperators and only keep links that
    # go deeper
    depth = link.scan("|").count
    dec.reject! { |d| d[:url].scan("|").count <= depth }
    dec
  end

  # Returns the root links matching the given strings. One hash in the
  # form of { :url => "", :title => "" } is returned for each search
  # item. If there are multiple matches for a string, only the first is
  # returned.
  def self.find_certain_roots(search)
    raise "Search needs to be an Array" unless search.is_a?(Array)
    urls = LSF.find_suitable_urls
    return *search.map { |s| urls.detect { |x| x[:title].include?(s) } }
  end

  def self.set_debug=(v)
    @@debug = v ? true : false
  end

  # prints a debug message if enabled.
  def self.debug(text)
    return unless @@debug
    print (" | "*@@level).strip + " "
    puts text
  end

  # Appends to given file unless delete is specified. If no name is
  # given will write to a default file name.
  def self.get_file(name = nil, delete = false)
    name = "lsf_parser_out.html" if name.nil?
    File.delete(name) if delete && File.exists?(name)
    return File.new(name, "a")
  end

  def self.toplevel
    TOPLEVEL
  end
end

class LSFProf
  attr_accessor :id, :mail, :tele, :first, :last, :title, :akad

  # Creates an LSFProf from the given Hash. Raises for all keys that are
  # not supported by the class.
  def initialize(hash = {})
    hash.each do |k,v|
      raise "LSFProf doesn’t support #{k}" unless self.respond_to?("#{k}=")
      self.send("#{k}=", v)
    end
  end

  def eval_always?
    self.last == "von Hahn" || self.id == "12949" # Both "von Hahn"
  end

  def mailhref
    return self.last if mail.nil? || mail.empty?
    "<a href=\"mailto:#{self.mail}\">#{self.last}</a>"
  end

  # Overwrite hash function as otherwise array#uniq doesn’t work
  def hash
    id
  end
end

class LSFLecture
  attr_accessor :id, :name, :times, :rooms, :profs, :type, :facul, :sws
  attr_accessor :lang, :est_part, :detail_time, :note, :link, :facul_name

  # Creates an LSFLecture from the given Hash. Raises for all keys that
  # are not supported by the class.
  def initialize(hash = {})
    hash.each do |k,v|
      raise "LSFLecture doesn’t support #{k}" unless self.respond_to?("#{k}=")
      self.send("#{k}=", v)
    end
  end

  # Overwrite hash function as otherwise array#uniq doesn’t work
  def hash; id end

  def eval_always?
    self.type == "Grundvorlesung" || self.type == "Kursvorlesung" || self.name =~ /Programmierkurs/i
  end
end

# For convenience reasons, many elements are simply strings instead of
# classes. Commands useful to each of these types is therefore included
# in the String class.
class String
  # define some stoptypes that we do not want to include
  def is_stop_type?
    cmp = self.downcase
    ["übung", "kolloquium", "hauptseminar", "colloquium", \
      "prüfung", "oberseminar"].include?(cmp)
  end

  # define some stopnames that we do not want to includes
  def is_stop_name?
    self =~ /^Werkstatt/i
  end

  # define some stoprooms that we cannot evaluate (e.g. Mannheim, Heilbronn)
  def is_stop_room?
    self =~ /^MA/
  end

  # Replaces long names in rooms with shorter, but still clear ones.
  def shorten_room
    self.gsub("Philos.-weg", "Philw.") \
      .gsub("Alb.-Ueberle-Str", "A-Ueb-Str") \
      .gsub("Mönchhofstr", "Mönchh") \
      .gsub("Speyererstr", "Spey.") \
      .gsub("Gesellschaft für Schwerionenforschung", "G. f. Ionenforsch.") \
      .gsub("Besprechungsraum", "Bsprchngsrm") \
      .gsub("Medienzentrum Raum", "R") \
      .gsub("Seminarraum", "Semnarrm")
  end

  # converts all times in the format of 11:15 into HTML and also
  # abbreviates some strings.
  def htmlify_times
    self.gsub(/([0-9]):([0-9]{2})/, '\1<sup><small>\2</small></sup>') \
      .gsub(/20([0-9]{2})/, '\1') \
      .gsub("Einzel", 'Enzl')
  end

  # takes a (html) string and applies some magic so it can be nicely
  # inserted as cell content in a TeX table,
  def to_table_cell_tex(escape = true)
    cnt = self.gsub('<br>', "\n").strip_html.strip
    cnt = cnt.escape_for_tex if escape
    cnt = cnt.gsub("\n", '\linebreak{}')
    cnt
  end

  # parses LSF parser’s default time output into nice TeX. If a course
  # is given, applies some magic to make the checkbox.
  def time_magic_tex(course = nil)
    s = self.gsub(/([0-9]+)<sup><small>([0-9]+)<\/small><\/sup>/,  "\\time{\\1}{\\2}")
    s.gsub!("-", "--")
    return "$\\Box$ #{s}" unless course
    begin
      cdesc = course.description.strip.gsub(/[^a-z0-9]/i, "")[0..3].gsub(/h$/, "")
      sdesc = s[0..1] + s.match(/time\{([0-9]+)\}/)[1].gsub(/0([1-9])/, "\\1")
      (cdesc.downcase == sdesc.downcase ? "$\\boxtimes$ " : "$\\Box$ " ) + s
    rescue
      # probably the regex didn’t match and we accessed an invalid array
      # item. Take that as “no match”
      "$\\Box$ #{s}"
    end
  end
end


class REXML::Element
  # get the text content of the first element with the given name.
  # ignores prefixes. Returns default if no valid results can be
  # found. Unless specified, default is nil.
  def content(name, default = nil)
    begin
      self.get_elements("*[local-name()='#{name}']").first.text.strip
    rescue
      default
    end
  end
end


class LSF
  # Prints the gathered LSF data in a nice view that allows collecting
  # who evaluates which lecture. Only includes lectures that have been
  # set in Seee (compares titles). Tries to extract data from seee and
  # fill it in, if possible.
  def self.print_final_tex(data)
    data = data.dup
    LSF.connect_rails
    # find courses in active termss
    ct = Term.currently_active.map { |t| t.courses }.flatten
    ctt = ct.map { |c| c.title }
    # keep only courses in seee
    data.reject! { |x| !ctt.include?(x.name) }
    data.sort! { |x,y| x.name <=> y.name }
    # create course.title ⇒ course Hash for easy data lookup
    courses = Hash[ct.collect { |c| [c.title, c] }]
    ERB.new(RT.load_tex("../lsf_parser_final")).result(binding)
  end

  # prints all given lectures into a list.
  def self.print_pre_tex(input)
    input = input.dup
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
      if d.eval_always? || profs.any? { |p| p.eval_always? }
        box = '$\boxtimes$'
      else
        box = '$\Box$'
      end
      profs = profs.collect { |p| p.last }.uniq.join(", ")
      [box, d.name, d.type, d.lang[0..2], profs]
    end.compact.uniq

    ERB.new(RT.load_tex("../table")).result(binding)
  end



  def self.print_allmighty_csv(data)
    s = CSV.generate({:headers => true}) do |csv|
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

  def self.print_zuv_eval_csv(data)
    s = CSV.generate({:headers => true}) do |csv|
      csv << ["Funktion", "Anrede", "Titel", "Vorname", "Nachname", "E-Mail-Adresse", "Lehrveranstatlung: Name/Titel", "Lehrveranstaltungskennung laut LSF", "Lehrveranstaltungsort(e)", "Hier können Sie eintragen: 1) Von welcher studienorganisatorischen Einheit wird die Lehrveranstaltung angeboten (relevant bei Import / Export)? 2) Für welchen / welche Studiengänge wird die LV angeboten?", "Lehrveranstaltungsart", "erwartete Teilnehmer / benötigte Fragebögen", "weitere/Sekundär-Dozenten", "Sprache", "veranschlagte SWS", "Leistungspunkte", "Modulzugehörigkeit (zu welchem Modul gehört die LV? Ggf. Kürzel angeben) --> ggf. bei Studiengang mit eintragen?", "Rhythmus (Blockveranstaltung oder wöchentlich)", "Wochentag", "Zeit (Uhrzeit)", "Dauer (von bis)", "Präsenzveranstaltung oder Moodle-Kurs / E-Learning", "Pflichtveranstaltung für welchen Studiengang / welche Studiengänge?", "Wahlpflichtveranstaltung für welchen Studiengang / welche Studiengänge?", "Semester", "Studienjahr"]
      data.each do |d|
        profs = d.profs.flatten.uniq unless d.profs.nil?
        if profs.empty?
          csv << ["", "", "", "", "", "", d.name, d.id, d.rooms.join(", "), "", "", d.est_part, "KEINE", d.lang, d.sws == 0 ? "" : d.sws, "", "", d.detail_time[:ryth], d.detail_time[:wday], d.detail_time[:time], d.detail_time[:date], "", "", "", ""]
          next
        end

        profs.each do |p|
          csv << ["", "", p.title, p.first, p.last, p.mail, d.name, d.id, d.rooms.join(", "), "", "", d.est_part, profs.size == 1 ? "KEINE" : "insg. #{profs.size}, siehe anliegende Zeilen",  d.lang, d.sws == 0 ? "" : d.sws, "", "", d.detail_time[:ryth], d.detail_time[:wday], d.detail_time[:time], d.detail_time[:date], "", "", "", ""]
        end
      end
    end
    s
  end


  def self.print_sws_sheet(data)
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
      s << LSF.list_profs_html(allprofs).strip_html + "\n"
    end
    s
  end

  def self.print_yaml_kummerkasten(data, faculty)
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
      profs = profs.collect { |x| "{mail: #{x.mail}, name: #{x.last}}" }

      s << "  - type:  #{type}\n"
      s << "    name:  \"#{d.name.gsub(/\([a-z\s,.]+\)$/i, "").gsub('"', "'")}\"\n"
      s << "    profs: [#{profs.join(", ")}]\n"
      s << "    sem:   #{LSF.term}\n"
      s << "    fach:  #{faculty}\n"
    end
    s
  end
end
