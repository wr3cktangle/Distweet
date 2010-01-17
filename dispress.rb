#!/usr/bin/env ruby
#
#dispress.rb
#a dissociated press (http://en.wikipedia.org/wiki/Dissociated_press) class for Ruby
#built for to give "life" to my twitter bot
#
#Also, credit to Mark V. Shaney (http://en.wikipedia.org/wiki/Mark_V._Shaney)
#for the idea and the inspiration
#

class Dispress

   #Enumeration class just for the enumeration modes
   class DispressMode
     Word = 0
     Character = 1
     Char = 1
   end

   @@Unit_Limit = 65535     #a default max length. The fact it's a unsigned int's max
                            #is not important. I just chose it for its familiarity and largeness
   @@Char_Limit = 214748364 #a default max length. IntMax just for fun
   @@Mode_Regexp = [/ /,//] #Regular expressions for splitting the source text into arrays of the unit
                            #A careful reader will note how they correspond to the values in DispressMode
   @@Mode_Joiner = [" ",""]

   
   #The first three of the attr_reader variables have mutator methods, but I needed to do more with them
   attr_reader :source_text, :n, :mode, :markov_chains, :source_array, :previous_mode, :previous_n, :ignore_case
   attr_accessor :unique_markov_chains
   
   def initialize(initial_source, initial_n = 1, initial_mode = Dispress::DispressMode::Word, ignore_case = false, unique_chains = true)     
     @unique_word_chain = unique_chains
     @n = initial_n
     @mode = @previous_mode = initial_mode
     @ignore_case = ignore_case
     self.source_text = initial_source #must be done last, as changing the source automatically rebuilds the Narkov Chains, but n and mode must be set first
   end
   
   #Using the source text, it builds the markov chains required for the dispress function
   def build_chains()
     @markov_chains = {}
     @source_array = @source_text.split(@@Mode_Regexp[@mode])               #break up the source at the spaces
     
     if @ignore_case
       @source_array.each {|w| w.downcase! }         
     end
     
     return nil if @n > @source_array.length                               #only failsafe
     (0...(@source_array.length - @n)).each do |i|                         #loop through every unit but the last N units building the markov chains (nothing follows the last N units)
        key = String.new
        (0...@n).each do |j|
          key = key + @source_array[i+j]                                   #concatenate the next n units to form key
        end
        @markov_chains[key] = Array.new if @markov_chains[key] == nil      #create a new markov chain for the word if it's the first time we've encountered the word
        @markov_chains[key].push(@source_array[i + @n])                    #append the next unit in source_array to the markov chain for the current unit
        @markov_chains[key].uniq! unless @mode == Dispress::DispressMode::Character || @unique_markov_chains == false  #unless told to do otherwise, keep markov chains unique.
           #reasons to not keep it unique may include to allow the probability of a word being chosen to directly correlate with the usage in the source,
           #i.e. if the word "dog" follows the word "cat" 75% of the time in the source text, "dog" will have a 75% chance of being chosen after the word
           #"cat" (theoretically of course)
        end     
   end
   private :build_chains
   
   #If the mode is changed, rebuild the markov chains
   def mode=(new_mode)
     @mode , @previous_mode = new_mode, @mode
     build_chains() if @mode != @previous_mode && @previous_mode != nil && @previous_mode != ""
   end
   
   #when the @source_text is changed, we need to purify it, and then (re)build the word chains
   def source_text=(new_source)
     @source_text = purify(new_source)     
     build_chains()
   end
   
   #when n is changed, rebuild the markov chains
   def n=(new_n)
     @n , @previous_n = new_n, @n
     build_chains() if @n != @previous_n && @previous_n != nil && @previous_n != 0
   end
   
   
   #purifies a String
   #intended for the @source_text
   #changes all non-space whitespace to be a space, and then removes the excess spaces
   #this makes sure @source_txt.split(/ /) will work properly.
   def purify(str)
     return str.to_s.gsub(/[\r\n\t]/," ").strip.squeeze(" ")
   end
   private :purify #make purify private - no need for outsiders to worry about this method
   
   #the method everyone will be most excited about
   #It performs the actual dispress functionality, but requires the markov chains created 
   #from the source text in build_chains
   #doing it this way also lets me build the chains once, and dispress as many times as I need
   #as long as N and mode stay the same.
   def dispress(unit_limit, char_limit = -1, beginning_output = [])
      #Note: I could save memory (I'm assuming) by using output_a to only store the last N units instead of all the units.
      #      After forming the last_key (which would be more straightforward as the indices would use (0...N) instead of
      #      (-N..-1)), pop the array to remove the first unit, which is no longer needed and then push on the most recent
      #      as I already do
      #      This creates a revolving door, so I never have more than N units in the array's memory, which would be fine for
      #      how I use it now with the exception that I use the array length to check against the unit length, but I could just
      #      keep a counter variable and increment when I push.  Hmmmmm.....
      #      I could even just decrement unit_limit and check that it's greater than zero, thus eliminating the counter variable
      #      and using one I already have. Let me tell you what, it's good to not have to worry about memory usage like I hear
      #      about at school.
   
      if @markov_chains.class != Hash || @markov_chains.length == 0
        return
      end
      #make sure our limits are set
      unit_limit, char_limit = unit_limit.to_i, char_limit.to_i      
      unit_limit = @@Unit_Limit if unit_limit < 1
      char_limit = @@Char_Limit if char_limit < 1
      
      #i keep an array of the units used in the output (output_a) and the actual string returned
      #as output (output_s).
      output_a = (beginning_output.class == Array && beginning_output.length > 0) ? beginning_output : Array.new()
      output_s = (beginning_output.class == Array && beginning_output.length > 0) ? beginning_output.join(@@Mode_Joiner[@mode]) : String.new()
      #our start index
      start_index = rand(@source_array.length - @n + 1)
      
      #start with N consecutive units from a random point in the source
      (0...@n).each do |i| 
         output_a.push(@source_array[start_index + i])
         output_s = output_s + output_a[-1] + @@Mode_Joiner[@mode]
         #output_s = output_s + " " if @mode == Dispress::DispressMode::Word
      end           
      
      while (output_s.length < char_limit && output_a.length < unit_limit) do
         #build last_key from the last @n units and use it to access the markov chains hash to get our next unit
         last_key = String.new
         neg_n = -1 * @n
         (neg_n..-1).each do |i| 
           last_key = last_key + output_a[i]
         end
         last_units_array = @markov_chains[last_key]         
         break if last_units_array == nil || last_units_array.length == 0 #stop dispressing if we won't be able to go farther.
         output_a.push(last_units_array[rand(last_units_array.length)])
         output_s = output_s + output_a[-1] + @@Mode_Joiner[@mode]
         #output_s = output_s + " " if @mode == Dispress::DispressMode::Word
      end
      
      #for sake of readability and believability, trim off probable incomplete "words" at start and end of output string
      output_s = output_s[output_s.index(" ")+1,output_s.rindex(" ") - output_s.index(" ")].strip if @mode == Dispress::DispressMode::Character
      
      return output_s.strip
   end    
   
   def read_source_from_file(file_name, line_limit = -1)
     file_name = file_name.to_s unless file_name.class == String
     f = File.open(file_name)
     
     st = String.new
     begin
       while (line_limit > 0 || line_limit < 0) do
         st = st + f.readline
         line_limit = line_limit - 1
       end
     rescue EOFError
       f.close  
     end
        
     self.source_text = st
   end
   
   #reads a file line by line and returns the contents in a string
   # I mostly did not want to rewrite this for all my programs using this class,
   # so that's why this is here even though it doesn't quite fit in
   # Note: "Static" method, so doesn't affect any actual objects
   def self.create_source_from_file(file_name, line_limit = -1)
     file_name = file_name.to_s unless file_name.class == String
     f = File.open(file_name)
          
     st = String.new
     begin
       while (line_limit > 0 || line_limit < 0) do
         st = st + f.readline
         line_limit = line_limit - 1 unless line_limit < 0
       end
     rescue EOFError
       f.close  
     end
     
     return st
   end
end



if __FILE__ == $0
  word_n,char_n = 2,3
  
  case ARGV.length
    when 1
      word_n = ARGV[0].to_i
    when 2
      word_n = ARGV[0].to_i
      char_n = ARGV[1].to_i
  end
  
  puts "Reading source file..."
  $stdout.flush
  t1 = Time.now
  #other sources: '/public-domain/Alice In Wonderland.txt' and '/public-domain/Shakespeare.complete.txt'
  st = Dispress::create_source_from_file("source.txt")
  t2 = Time.now
  line_count = st.count("\n").to_s
  word_count = st.count("\n ").to_s
  char_count = st.length.to_s
  avg_word_size = (st.length.to_f / word_count.to_f).to_s
  puts "Finished reading source file in " + (t2 - t1).to_s + " seconds."
  puts "lwc: " + line_count + " lines, " + word_count + " words, " + char_count + " characters" 
  puts "Average word length: " + avg_word_size + " characters."
  sf = File.open("source_stats.txt","a")
  sf.write(t1.to_s + " " +  line_count + " " + word_count + " " + char_count + " " + avg_word_size + "\n")
  sf.close
  $stdout.flush
  
  1.times do |x|
    puts "Starting Cycle " + (x + 1).to_s + " of 5 " + Time.now.to_s
    $stdout.flush
    d = Dispress.new(st,word_n,Dispress::DispressMode::Word)
    f = File.open("output.txt","a")
    f.write(d.dispress(150, 130) + "\n\n")
    f.write(d.dispress(150, rand(89) + 40) + "\n\n")
    f.write(d.dispress(150, rand(40) + 89) + "\n\n")
    f.write(d.dispress(150 + rand(400)) + "\n\n")
    f.close
    
    #d = Dispress.new(st,word_n,Dispress::DispressMode::Word, true, false)
    #f = File.open("output.txt","a")
    #f.write(d.dispress(150, 130) + "\n\n")
    #f.write(d.dispress(150, rand(89) + 40) + "\n\n")
    #f.write(d.dispress(150, rand(40) + 89) + "\n\n")
    #f.write(d.dispress(150 + rand(400)) + "\n\n")
    #f.close
    #d = Dispress.new(st,char_n,Dispress::DispressMode::Character)
    #f = File.open("output_by_char.txt","a")
    #f.write(d.dispress(139) + "\n\n")
    #f.write(d.dispress(rand(89) + 40) + "\n\n")
    #f.write(d.dispress(139) + "\n\n")
    #f.close    
  end
  
  puts "All done. " + Time.now.to_s
end