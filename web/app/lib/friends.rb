# contains Friends class which handles matching names similar to each
# other. Define FRIENDS_PATH if you want to appear the true/false
# friends files to appear elsewhere. The class is tailored for import,
# thus inly Friends.new.uniq_sim(array) will be useful for other uses.

require "rubygems"
require "text"

FRIENDS_PATH = "#{GNT_ROOT}/tmp/friends/" unless defined?(FRIENDS_PATH)

class Friends
  TF_PATH = FRIENDS_PATH + "true_friends.txt"
  FF_PATH = FRIENDS_PATH + "false_friends.txt"
  WHITE = Text::WhiteSimilarity.new

  def initialize
    @true_friends ||= {}
    @false_friends ||= {}
    FileUtils.mkdir_p(IMPORT_PATH)
    write_default_friends
    load_friends
  end

  # returns similar items from given data collection. Matching is done
  # by data[:title]
  def find_similar(title, data)
    data.select { |d| similar?(d[:title], title) }
  end

  # Makes each entry in the array unique, taking similar entries into
  # account (by asking the user).
  def uniq_sim(arr)
    a = arr.uniq
    rem = []
    (0..a.size-1).each do |x|
      (x+1..a.size-1).each do |y|
	next if x == y
	rem << a[y] if similar?(a[x], a[y])
      end
    end
    return a-rem
  end

  # returns the candidate most similar to item. Does not query user.
  # Will return an item, even if they are totally dissimilar
  def find_most_similar(item, candidates)
    sim = -1
    can = nil
    candidates.each do |c|
      s = WHITE.similarity(item, c)
      next unless s > sim
      sim = s
      can = c
    end
    can
  end

  private
  def add_false_friend(a, b)
    a, b = a.strip.downcase, b.strip.downcase
    @false_friends[a] ||= []
    @false_friends[a] << b
    @false_friends[a].uniq!
    @false_friends[b] ||= []
    @false_friends[b] << a
    @false_friends[b].uniq!
    write_friends(:false)
  end

  def add_true_friend(a, b)
    a, b = a.strip.downcase, b.strip.downcase
    @true_friends[a] ||= []
    @true_friends[a] << b
    @true_friends[a].uniq!
    @true_friends[b] ||= []
    @true_friends[b] << a
    @true_friends[b].uniq!
    write_friends(:true)
  end

  # returns true if the two arguments are not known false friends, their
  # similarity is large enough according to White-test and the users
  # agrees they are similar.
  def similar?(x, y)
    a, b = x.downcase, y.downcase
    # similar when titles match
    return true if a == b
    # also similar when titles match via true friends
    return true if true_friends?(a, b)
    # definitely not similar if it was dismissed before
    return false if false_friends?(a, b)
    # also similar if largely similar according to white test and the
    # user agrees
    WHITE.similarity(a, b) >= 0.7 && ask(a, b)
  end

  # asks the user if the two given arguments mean the same. Depending on
  # the answer, the result is stored into true/false friends.
  def ask(a, b)
    q = "Do the following two mean the same? @@opt\n  #{a}\n  #{b}"
    y = get_user_yesno(q, :none)
    y ? add_true_friend(a, b) : add_false_friend(a, b)
    y
  end

  def true_friends?(x, y)
    a, b = x.downcase, y.downcase
    @true_friends[a] && @true_friends[a].include?(b)
  end

  def false_friends?(x, y)
    a, b = x.downcase, y.downcase
    @false_friends[a] && @false_friends[a].include?(b)
  end

  # writes the current list of friends in memory to the files.
  def write_friends(which)
    return unless @write_enabled
    File.open(FF_PATH, 'w') do |f|
      @false_friends.each do |k,vv|
	vv.each { |v| f.write("#{k} ≠ #{v}\n") }
      end
    end if [:false, :both].include?(which)
    File.open(TF_PATH, 'w') do |f|
      @true_friends.each do |k,vv|
	vv.each { |v| f.write("#{k} ⇔ #{v}\n") }
      end
    end if [:true, :both].include?(which)
  end

  # writes know true/false friends into the default file locations if
  # they do not exist yet.
  def write_default_friends
    unless File.exist?(TF_PATH)
      tf = <<-TrueFriendsEnd
        Höhere Analysis ⇔ Analysis 3
        Algebra I       ⇔ Algebra 1
        Analysis I      ⇔ Analysis 1
        Analysis II     ⇔ Analysis 2
        Einführung in die Numerik ("Numerik 0") ⇔ Numerik 0
        Einführung in die Numerik               ⇔ Numerik 0
        Einführung in die Wahrscheinlichkeitstheorie ⇔ Einführung in die Wahrscheinlichkeitstheorie und Statistik
        TrueFriendsEnd
      File.open(TF_PATH, 'w') {|f| f.write(tf.downcase) }
    end
    unless File.exist?(FF_PATH)
      ff = <<-FalseFriendsEnd
        Lineare Algebra 1 ≠ Algebra 1
        Lineare Algebra 1 ≠ Liealgebren
        Liealgebren       ≠ Analysis 1
        Liealgebren       ≠ Analysis 3
        Algebra 1         ≠ Analysis 1
        Algebra 1         ≠ Lineare Algebra 1
        Analysis 1        ≠ Analysis 3
        FalseFriendsEnd
      File.open(FF_PATH, 'w') {|f| f.write(ff.downcase) }
    end
  end

  # loads true/false friends into memory from files
  def load_friends
    @write_enabled = false
    File.open(TF_PATH, "r").each_line do |line|
      a, b = *line.split("⇔", 2)
      add_true_friend(a, b)
    end
    File.open(FF_PATH, "r").each_line do |line|
      a, b = *line.split("≠", 2)
      add_false_friend(a, b)
    end
    @write_enabled = true
  end
end
