#!/usr/bin/env ruby
#
#sourcebuilder.rb
#a class to build, clean, and store new source material for the
#dissociated press part of my twitterbot


#ToDo: Remove xmlsimple part and replace with crack. Also: possible to get JSON response?
#ToDo: Create a SourceHandler class based on this that is instantiated and tracks the file length
#        and will then only need to read in the whole file when first initialized and only when a 
#        trimming is needed.
#        This one class will replace the two threads in the bot.

require 'net/http'
require 'uri'
require 'xmlsimple'
require 'crack'
require 'cgi'


class SourceBuilder
  @@BasePage = "http://twitter.com"
  @@SearchPage = "http://search.twitter.com"
  @@SourceFile = "source.txt"
  @@WordListDir = "/wordlists/"
  @@Trim_At = 3000
  @@Trim_To = 1000
  
  
  #I want to store my source output in flat ASCII text files.
  #I also want to try to keep my source file limited to english tweets.
  #Unfortunately, twitter doesn't allow you to pull down only the latest tweets in a
  # specific language, though they do have language codes for search
  #They also do not specify the language of the tweet in the xml.
  #This led me to check all characters of a tweet if they're ASCII (not extended ASCII)
  # characters, and discard any tweets with "special" (non ASCII) characters.
  def self.build_source_latest()
    updates = String.new
    url = URI.parse(@@BasePage)      
    res = Net::HTTP.start(url.host, url.port) { |http| 
      http.get('/statuses/public_timeline.xml') }
          
    if(res.class == Net::HTTPOK)
      twitter = XmlSimple.xml_in(res.body, { 'KeyAttr' => 'name' })
      twitter["status"].each {|status|
        nothing_special = true
        this_status = CGI::unescapeHTML(CGI::unescape(status["text"][0]))
        (0...this_status.length).each {|i|
           if(this_status[i] > 127)
             nothing_special = false
             break;
           end
        }
        updates = updates + "\n" + status["text"][0] if nothing_special
      }  
    else
      return nil
    end
    
    return CGI::unescape(updates)
  end
  
  #Unlike the latest tweets, searching allows for a language code.
  #It also gives the option for results per page.
  #For my purposes, I only wanted english, and 50 rpp is good enough
  # for me, so i've hardcoded them into the search URL.
  #
  #The parameters here include the query phrase to search for, and
  # and an Array of (atti)tudes. 
  def self.build_source_search(query,tude=Array.new)
    query = CGI::escape(query.to_s)
    if(tude.class == Array && tude.length > 0)
      tude.each{|t|
        query+="&tude[]="+CGI::escape(t)
      }
    end    
    #puts "q=" + query + "\n"
    return "" if query.length > 120
    
    res = Net::HTTPResponse.new("","","")
    updates = String.new
    begin
      url = URI.parse(@@SearchPage)      
      res = Net::HTTP.start(url.host, url.port) { |http| 
        http.get('/search.json?lang=en&rpp=50&q=' + query) }
    rescue Timeout::Error
      #puts "\n\n*****\nError getting response - timeout\n*****\n\n"
      return ""
    rescue
      #puts "\n\n*****\nError getting response - generic\n*****\n\n"
      return ""
    end
       
    if(res.class == Net::HTTPOK)
      twitter = Crack::JSON.parse(res.body)
      twitter["results"].each {|status|
        nothing_special = true
	this_status = CGI::unescapeHTML(CGI::unescape(status["text"]))
	        (0...this_status.length).each {|i|
	           if(this_status[i] < 32 || this_status[i] > 127)
	             nothing_special = false
	             break;
	           end
	        }
        updates = updates + " " + status["text"] if nothing_special        
      }
    else
      return ""
    end
    
    return CGI::unescapeHTML(CGI::unescape(updates)) 
  end
  
  #Built in source building method using the search.
  def self.build(repeat_counter = 1, word_file = "", out_file = "")
     repeat_counter = repeat_counter.to_i < 1? 1: repeat_counter.to_i
     
     word_list_files = Array.new
     word_list_files.push(word_file) if (word_file != "" && File.exists?(word_file))
     query_words = Array.new
     output_file = out_file == "" ? @@SourceFile : out_file
     Dir.foreach(Dir.pwd + @@WordListDir) {|f| if f.include?(".txt") then word_list_files.push(Dir.pwd + @@WordListDir + f) end} unless word_list_files.length > 0
     
     if(word_list_files.length > 0)
       all_words = String.new
       filename = word_list_files[rand(word_list_files.length)]
       #puts "Opening " + filename
       $stdout.flush
       line_count = 0
       f = File.open(filename)
       begin
           while (true) do
             all_words = all_words + f.readline  
             line_count += 1
           end
       rescue EOFError
           f.close  
       end
       
       query_words = all_words.split(/[ \n\r\t]/).uniq
       #puts "Read in " + line_count.to_s + " lines with " + query_words.length.to_s + " words."
       $stdout.flush
     end
     
     if query_words.length == 0
       query_words = ["a","i","the","lefty","democrat","Alkaline Trio",
                    "Pete Yorn","Clarion","Golf","album","concert","politics",
                    "president","obama","republican", "barack", "is", "can",
                    "why", "cookie", "pa", "pennsylvania", "beer", "ireland",
                    "movie", "hospital", "right", "left", "eat", "milk", "office",
                    "#musicmonday", "yesterday", "oath", "crazy", "girl", "chick",
                    "boy", "guy", "dude", "lol", "rofl", "lmao", "cash", "job",
                    "school", "college", "work", "ice cream", "god", "catholic",
                    "jury", "path", "tree", "bird", "nature", "chipmunk",
                    "squirrel", "dance", "life", "sad", "fml", "tony danza",
                    "war", "peace", "love", "jesus", "dancing", "dance", "large",
                    "small", "amazing", "ajfitz03", "hat", "tunes", "pants", "new",
                    "tatoo", "magician", "dnd", "nintendo", "lips", "lip", "balm",
                    "stick", "purse", "ego", "sugar", "tea", "wine", "sandwich",
                    "mac", "cheese", "america", "canada","england","waffel", "lego",
                    "my", "back", "tiny", "zoo", "snow", "anger", "happy", "angry",
                    "democratic","democrats","republicans", "dancing", "dudes",
                    "boys","girls","chicks","men","women","trees", "nathan", "john",
                    "nikki", "kat", "lizzie", "cancer", "aaron", "me", "myself"].uniq
     end
     tudes = [":)",":(","?"]     
     
     repeat_counter = query_words.length / 2 if repeat_counter > query_words.length
     $stdout.flush
     
     repeat_counter.times do |x|     
       query = query_words[rand(query_words.length)]
       query_words.delete(query)
       
       tude = Array.new
       tude_chance = rand(30)
       #puts "tude_chance: " + tude_chance.to_s
       
       if([0,3,5,6].include?(tude_chance))
         tude.push(tudes[0])
       end    
       if([1,3,4,6].include?(tude_chance))
         tude.push(tudes[1])
       end
       if([2,4,5,6].include?(tude_chance))
         tude.push(tudes[2])
       end
         
       #perform a search, then remove words that begin with @ or # or contain http,rt,www,.com,ftp
       # this is to try to avoid @ replying to random people and forwarding possible spam
       possible_source = String.new
       possible_source += SourceBuilder::build_source_search(query,tude)
       possible_a = possible_source.gsub(/[\r\n\t]/," ").strip.squeeze(" ").split(/ /)
       possible_a.delete_if {|el| ((el[0,1] == "@" || el[0,1] == "#") && el.length > 1) || ["http","rt","www.",".com","ftp:"].inject(false){|is_bad,bad_el| (el.downcase.include?(bad_el) || is_bad)?true:false} }
       possible_source = possible_a.join(" ")
       #puts possible_source
       
       if(possible_source.strip.length != 0)
         f = File.open(output_file, "a")
         f.write(possible_source + "\n")
         f.close
       end
       
       #don't be the cause of a fail whale. Twitter is fragile enough as is.
       if (x < repeat_counter - 1)
         sleep_time = rand(10) + 5
         sleep(sleep_time)
       end
    end     
  end
  
  
  #quick hack to keep the source size until control so that
  # it stays kinda fresh while also not over stressing the
  # dispress algorithm.
  #Run a character dispress on the complete works of Shakespeare,
  # you'll get the idea.
  def self.trim_source(source_file = '')
    lines = []
    the_file = source_file == '' ? @@SourceFile : source_file
    
    return false unless File.exists?(the_file)
    
    f = File.open(the_file)
    begin
      while (true)
       lines.push(f.readline)      
      end
    rescue Exception => e
      #ignore
    ensure
      f.close  
    end
    
    return false if lines.length <= @@Trim_At
    
    lines.sort_by {rand}
    
    f = File.open(the_file, "w")
    begin
      (0...@@Trim_To).each {|i|
        f.write(lines[i])
      }
    ensure
      f.close
    end
    
    return true
    
  end
end

if __FILE__ == $0
  ARGV.each {|ar| print ar + " "}
  times_to_build = ARGV.length == 0 ?  (rand(10)+10) : ARGV[0].to_i 
  source_file = ARGV.length >= 2 ? ARGV[1] : ""
  output_file = ARGV.length >= 3 ? ARGV[2] : ""
  SourceBuilder::build(times_to_build, source_file, output_file)
end