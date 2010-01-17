require 'rss'
require 'shorten'

class BotRSS

  include Shorten
  
  attr_reader :rssFeeds, :lastRSSIndex

  def initialize(feedList)
    @rssFeeds = feedList
    @lastRSSIndex = @rssFeeds.length
  end
  
               
  def getNewsArticle
    
    if(@rssFeeds.length == 0)
      return ""
    end
    while((rssIndex = rand(@rssFeeds.length)) == @lastRSSIndex && @rssFeeds.length > 1)
      #for now, loop til we find a new one    
    end
      
    @lastRSSIndex = rssIndex
    rss_source = @rssFeeds[rssIndex]
	#puts rss_source
	#$stdout.flush
    rss = nil
    
    #puts "rssIndex " + rssIndex.to_s
    #puts "rssSource " + rss_source
    
    begin
      rss = RSS::Parser.parse(rss_source)
    rescue RSS::InvalidRSSError        
      rss = RSS::Parser.parse(rss_source, false)
    end
    
	#@rssFeeds.delete(rss_source)
	
    if(rss.channel.items.length == 0)
      return ""
    end
  	  
    topIndex = rand(rss.channel.items.length)
    topLink = rss.channel.items[topIndex].link
    topTitle = rss.channel.items[topIndex].title
    notShortened = topTitle + " " + topLink;
    
    if(notShortened.length <= 140)
      return notShortened
    end
    
    shortenedURL = shorten_isgd(topLink)[0].to_s;
      
    if(shortenedURL == nil || shortenedURL.length == 0)
      return "";
    end
    
    shortened = topTitle + " " + shortenedURL
    if(shortened.length <= 140)
      return shortened
    else
      return shortenedURL + " " + topTitle
    end  
  end
end

if __FILE__ == $0
  br = BotRSS.new(["http://feeds.digg.com/digg/topic/politics/popular.rss","http://pheedo.msnbc.msn.com/id/3032552/device/rss",
                   "http://topics.cnn.com/topics/feeds/rss/u_s_politics","http://rss.news.yahoo.com/rss/politics",
                   "http://feeds.foxnews.com/foxnews/politics/","http://feeds.digg.com/digg/topic/political_opinion/popular.rss",
  		   "http://feeds.digg.com/digg/topic/music/popular.rss","http://www.billboard.com/rss/news",
  		   "http://feeds.digg.com/digg/popular.rss","http://feeds.digg.com/digg/container/science/popular.rss",
		   "http://feeds.current.com/groups/music.rss","http://feeds.current.com/groups/news.rss"])
  5.times {|i|
    begin
      puts "#{i}: #{br.getNewsArticle}"
    rescue Exception => e
      puts "#{i}: Error in #{br.rssFeeds[br.lastRSSIndex]}"
      puts " #{e}"
    end
  }
end
