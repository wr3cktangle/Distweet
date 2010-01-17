#sourcehandler.rb
#  does source handling for the twitbot with text file source
#  jobs:
#    update source
#    trim source

require 'net/http'
require 'uri'
require 'crack'
require 'cgi'

class SourceHandler
  @@BasePage = "http://twitter.com"
  @@SearchPage = "http://search.twitter.com"
  
  attr_reader :source_file, :source_lines
  attr_accessor :trim_at, :trim_to, :word_list_dir, :search_terms

  def initialize(sf,ta = 3000,to = 1000, st = [])
    @source_file = sf
    @trim_at, @trim_to = ta, to
    @source_lines = 0
    @word_list_dir = "/wordlists/"
    @search_terms = st
    if(File.exists?(@source_file))
      f = File.open(@source_file)
      
      begin
        while(true)
          f.readline()
          @source_lines += 1
        end
      rescue Exception => e
        f.close()
      end
    else      
      f = File.new(@source_file, 'w')
      f.close()
    end

  end
  
  def handle_source
    if(@source_lines > @trim_at)
      self.trim_source
    end
    
    self.build()
  end
  
  def build()
    word_list_files = Array.new
    query_words = []
    
    if(@search_terms.length == 0)    
      Dir.foreach(Dir.pwd + @word_list_dir) {|f| if f.include?(".txt") then word_list_files.push(Dir.pwd + @word_list_dir + f) end}
      
      if(word_list_files.length > 0)
         all_words = String.new
         filename = word_list_files[rand(word_list_files.length)]
         line_count = 0
         begin
           all_word = IO.read(filename)        
         rescue
           return 0 
         end
         
         query_words = all_words.split(/[ \n\r\t]/).uniq
       else
         return 0
       end
     else
       query_word = @search_terms
     end
       
     tudes = [":)",":(","?"]     
       
     query = query_words[rand(query_words.length)]
       
     tude = Array.new
     tude_chance = rand(30)
         
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
     possible_source += self.__search(query,tude)
     possible_a = possible_source.gsub(/[\r\n\t]/," ").strip.squeeze(" ").split(/ /)
     possible_a.delete_if {|el| ((el[0,1] == "@" || el[0,1] == "#") && el.length > 1) || ["http","rt","www.",".com","ftp:"].inject(false){|is_bad,bad_el| (el.downcase.include?(bad_el) || is_bad)?true:false} }
     possible_source = possible_a.join(" ")
         
     if(possible_source.strip.length != 0)
       f = File.open(@source_file, "a")
       f.write(possible_source + "\n")
       f.close
       
        @source_lines += 1
     end  
    
  end
  
  def __search(query,tude=Array.new,rpp = 50, lang_code = 'en', ascii_only = true)
    base_page = "http://twitter.com"
    search_page = "http://search.twitter.com"
  
    query = CGI::escape(query.to_s)
    if(tude.class == Array && tude.length > 0)
      tude.each{|t|
        query+="&tude[]="+CGI::escape(t)
      }
    end    

    return "" if query.length > 120
      
    res = Net::HTTPResponse.new("","","")
    updates = String.new
    
    begin
      url = URI.parse(search_page)      
      res = Net::HTTP.start(url.host, url.port) { |http| 
      http.get('/search.json?lang=' + lang_code + '&rpp=' + rpp.to_s + '&q=' + query) }
    rescue Timeout::Error
      return ""
    rescue
      return ""
    end
         
    if(res.class == Net::HTTPOK)
      twitter = Crack::JSON.parse(res.body)
      twitter["results"].each {|status|      
      
        nothing_special = true
  	this_status = CGI::unescapeHTML(CGI::unescape(status["text"]))
  	
  	#if(ascii_only)
  	#  begin
        #  (0...this_status.length).each {|i|
        #    if(this_status[i] < 32 || this_status[i] > 127)
        #      nothing_special = false
        #      break;
  	#    end
  	#  }
  	#  rescue Exception => e2
  	#    puts this_status
  	#    puts this_status.class
  	#    puts this_status[0]
  	#    puts this_status[0].class
  	#    puts e2
  	#  end
  	#end
        updates = updates + " " + status["text"] if nothing_special        
      }
    else
      return ""
    end
      
    return CGI::unescapeHTML(CGI::unescape(updates)) 
  end
  #private :__search
  
  
  #Trims @source_file to @trim_to lines long
  # Does not trim based on byte size, as may be expected.
  # Also, does not trim off an end of the file, but instead
  #  removes a lines randomly
  def trim_source
    lines = []
            
    return false unless File.exists?(@source_file)        
    
    f = File.open(@source_file,'r')
    begin
      while(true)
        lines.push(f.readline().strip)
      end
    rescue Exception => e
      #
    ensure
      f.close()  
    end
    
    return false if lines.length <= @trim_at
        
    lines.sort_by {rand}
        
    f = File.open(@source_file, "w")
    begin
      @source_lines = 0
      (0...@trim_to).each {|i|
        f.write(lines[i] + "\n")      
        @source_lines += 1
      }
      
    ensure
      f.close
    end
        
    return true
        
  end  
end

if __FILE__ == $0
  sh = SourceHandler.new("sf_test.txt")
  puts sh.source_lines
  
  10.times{|i|
   sh.handle_source()
   puts sh.source_lines
   sleep(1)
  }
  puts " "
  
  
  f = File.new("sf_test2.txt",'w')
  (1...10000).each{|i|
    f.write("#{i}\n")
  }
  f.close
  
  sh2 = SourceHandler.new("sf_test2.txt")
  puts sh2.source_lines
  
  10.times{|i|
  sh2.handle_source()
  puts sh2.source_lines
  sleep(1)
  }
  
end
