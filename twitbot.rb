#! /usr/bin/env ruby
#
# twitbot.rb
#  an example bot using my other classes and modules
#  It is not a class of its own. Instead it is a group
#   of indefinitely running Threads that stay out of eachothers' way
#   using a single Mutex

require 'twitter'
require 'shorten'
require 'botrss'
require 'dispress'
require 'sourcebuilder'

if(ARGV.length != 2)
  raise " Usage: twitbot.rb [username] [password]"
end

semaphore = Mutex.new()
botname = ARGV[0]
botpass = ARGV[1]

trap("SIGINT"){     
    puts "Interrupt received #{Time.now}"
    puts "Killing threads and exiting\n"
    Thread.list.each {|thread| thread.kill}
    puts "Threads killed" #not reached, i believe
}

#depending on your version of the Twitter gem, you may need to use the old method
# Old way may be broken for new versions of Twitter gem
bot = Twitter::Base.new(Twitter::HTTPAuth.new(botname, botpass));
#bot = Twitter::Base.new(botname, botpass);

br = BotRSS.new(["http://feeds.digg.com/digg/topic/politics/popular.rss","http://pheedo.msnbc.msn.com/id/3032552/device/rss",
                 "http://topics.cnn.com/topics/feeds/rss/u_s_politics","http://rss.news.yahoo.com/rss/politics",
                 "http://feeds.foxnews.com/foxnews/politics/","http://feeds.digg.com/digg/topic/political_opinion/popular.rss",
		 "http://feeds.digg.com/digg/topic/music/popular.rss","http://www.billboard.com/rss/news",
		 "http://feeds.digg.com/digg/popular.rss","http://feeds.digg.com/digg/container/science/popular.rss",
		 "http://feeds.current.com/groups/music.rss","http://feeds.current.com/groups/news.rss"])
		 
#Start the threads.

sourceThread = Thread.new {
   puts "Source thread started #{Time.now}"         
   extra_sleep_time = 0
   
   while(true)
      timeToSleep = (1 + rand(3)) * 3600).to_i
      dt = Time.now + timeToSleep
      puts "Source thread sleeping until #{dt}"
      sleep(timeToSleep);
      
      puts "Source thread woke up at #{Time.now}"
      semaphore.synchronize {
        puts("Source got semaphore")
  	begin
          SourceBuilder::build(30, "", "")    
          puts "Source thread built source at #{Time.now}"		
        rescue
	  puts("Problem with building source " + $!)
	end
      }		
   end
   
   puts "Source thread made it out of the loop - uh oh? #{Time.now}"
}

trimThread = Thread.new{
  puts "Source trim thread started #{Time.now}"         
   
  while(true)   
    puts "Trim thread woke up at #{Time.now}"
    semaphore.synchronize {
      puts("Trim got semaphore")
      begin
        trimmed = SourceBuilder::trim_source("")  
        did_not_trim = trimmed ? "" : "not "
        puts "Source " + did_not_trim + "trimmed at #{Time.now}"		
      rescue
 	puts("Problem with trimming source. " + $!)
      end
    }
    timeToSleep = ((4 + rand(4)) * 3600).to_i
    dt = Time.now + timeToSleep
    puts "Trim thread sleeping until #{dt}"
    sleep(timeToSleep);
  end
    
  puts "Trim thread made it out of the loop - uh oh? #{Time.now}"
}


postThread = Thread.new {
   sourceFiles = ["source.txt"] #could also include 'Shakespeare.complete.txt' and Alice In Wonderland.txt'
  
   puts "Post thread started #{Time.now}"
   if(rand(100) == 1)
      bot.update("awww. just woke up from a good nap");
   end
  
   while(true)
      timeToSleep = ((3 + rand(7)) * 3600).to_i
      dt = Time.now + timeToSleep
      puts "Post thread sleeping until #{dt}"
	  
      sleep(timeToSleep);
	  
      puts "Post thread woke up at #{Time.now}"
      semaphore.synchronize {
	puts("Post got semaphore")
  	begin
          st = Dispress::create_source_from_file(sourceFiles[rand(sourceFiles.length)])	    
          d = Dispress.new(st,rand(2)+2,Dispress::DispressMode::Word, rand(3) > 0)	    
          distweet =  d.dispress(150, 130)
          puts("Posting #{Time.now}: #{distweet}")
          bot.update(distweet)
          puts "Post thread posted at #{Time.now}"    
        rescue
          puts("Problem with the ol' posting thread " + $!)
        end	 
      }
   end
   
   puts "Post thread made it out of the loop - uh oh? #{Time.now}"   
}


newsThread = Thread.new {
   puts "News thread started #{Time.now}"        
   
   while(true)
      timeToSleep = (3 + rand(11)) * 3600).to_i
      dt = Time.now + timeToSleep
      puts "News thread sleeping until #{dt}"
      sleep(timeToSleep);

      puts "News thread woke up at #{Time.now}"
      semaphore.synchronize {
	puts("News got semaphore")
  	begin
          news = br.getNewsArticle()
      
          if(news.class == String && news.length > 0)
            puts(news)
	    bot.update(news)
          end
          puts "News thread posted at #{Time.now}"
        rescue
	  puts("Oh noes! News thread has failed again!!! " + $!)
        end
      }
   end
   puts "News thread made it out of the loop - uh oh? #{Time.now}"
}



Thread.list.each {|thread|
   thread.join
}
      
