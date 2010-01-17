require 'net/http'
require 'uri'
require 'crack'
require 'cgi'

module Shorten
  #It is preferable to use shorten_bitly over shorten_isgd for multiple URLs, as bit.ly provides the ability to shorten
  # multiple URLs with one call, while is.gd and tinyurl.com only allow one URL per call.
  # That being said, it was preferable to code shorten_isgd and shorten_tinyurl as the apis were much more basic and therefore simpler.

  #shorten_bitly
  # parameters:
  #  links = array of strings with the URLs to be shortened (can be a string if one link. Will be converted to an array)
  #  login = username of registered bit.ly account
  #  apikey = api key of registered bit.ly account  
  def shorten_bitly(links, login, apikey)
     bitlypage = "http://api.bit.ly"
     output = []
     
     if(links.class == String)
       links = [links]
     end
     
     if(links.class != Array || links.length == 0)
        return output;
     end
     
     #strip spaces and encode URLs
     links.each_index {|i| links[i] = CGI::escape(links[i].strip())}
     
     #create a string with all the URLs
     longurl = "&longUrl=" + links.join("&longUrl=")
     
     #get the shortened links, hopefully
     url = URI.parse(bitlypage)      
     res = Net::HTTP.start(url.host, url.port) { |http| 
        http.get("/shorten?version=2.0.1&format=json&login=" + login + "&apiKey=" + apikey + "&history=1" + longurl) }
     
     #parse good responses
     if(res.class == Net::HTTPOK)
        parsed = Crack::JSON.parse(res.body)
        
        #if there's a problem with bit.ly with the entire shorten attempt, return 
        if(parsed["errorCode"].to_i != 0)
          puts parsed["errorMessage"]
          puts parsed["errorCode"]
          puts parsed["statusCode"]
          puts "overall error 0"
          return output
        end
        
        #get the response for each URL. It's possible for individual URL shorten attempts to fail
        # but for the attempt to be a success.
        links.each{|lnk|
          #we escaped the link earlier, so unescape it now. Entirely necessary.
          lnk = CGI::unescape(lnk)  
          
          if(parsed["results"][lnk]["errorCode"].to_i == 0)            
            output.push(parsed["results"][lnk]["shortUrl"])
          else
            output.push("")
          end
        }                
     end 
     
     return output
  end
  
  
  #shorten_isgd
  # parameters:
  #  links = array of strings with the URLs to be shortened (can be a string if one link. Will be converted to an array)
  #
  # Note: While multiple links are supported, I recommend shorten_bitly to shorten multiple links, if possible.
  def shorten_isgd(links)
    site_base = "http://is.gd"
    api_page = "/api.php?longurl="
    
    return __shorten_simple(site_base, api_page, links)
  end
  
  #shorten_tinyurl
  # parameters:
  #  links = array of strings with the URLs to be shortened (can be a string if one link. Will be converted to an array)
  #
  # Note: While multiple links are supported, I recommend shorten_bitly to shorten multiple links, if possible.
  def shorten_tinyurl(links)
    site_base = "http://tinyurl.com"
    api_page = "/api-create.php?url="
    
    return __shorten_simple(site_base, api_page, links)
  end
    
  private
  #private method used by shorten_isgd and shorten_tinyurl as they're APIs were near identical, just different pages,
  # so it seemed easier to make one function to do the real work, and two functions to use it.
  def __shorten_simple(site_base, api_page, links)
   
   output = []
           
   #convert input to an array if it's a string
   if(links.class == String)
     links = [links]
   end
   
   if(links.class != Array && links.length == 0)
     return output;
   end
   
   url = URI.parse(site_base)
   
   #a call to the is.gd api must be made for each link. .
   links.each {|lnk|
     lnk = CGI::escape(lnk.strip)
   
     res = Net::HTTP.start(url.host, url.port) { |http| 
       http.get(api_page + lnk) }
              
       if(res.class == Net::HTTPOK)
         output.push(res.body)
       else
        output.push("")
       end
   }
           
   return output
  end
end

if __FILE__ == $0
  include Shorten
  website = "http://www.google.com"
  sites = ["http://www.kingdomofloathing.com","http://www.hrwiki.org"]
  
  puts(shorten_isgd(website))
  puts(shorten_isgd(sites))
  puts()
  puts(shorten_tinyurl(website))
  puts(shorten_tinyurl(sites))
  puts()
end