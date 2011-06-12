#####################################################################################################################
# TtT_helpers.rb
# Kate Starbird Jan 21, 2011
# helper code for Tweak the Tweet parsing / storage

require "rubygems"

#####################################################################################################################
# TtT helper functions

def is_RT(text)  
  if text.downcase =~ /(r @|rt @|via @)/
    return true
  end
  return false
end

# returns true if the tweet contains a tag that indicates probable TtT
def isTtT(text)
  if text.downcase =~ @TtT_filter_reg_ex
    return true
  end
  return false
end

def print_tweet_and_values(tweet, parsed_values)
  print "Tweet\n"
  tweet.each_pair do |cat, value|
    print cat + ": " + value + "\n"
  end
      
  print "Parsed Values - Record\n"
  parsed_values.each_pair do |cat, value|
    print cat + ": " + value + "\n"
  end
  
  print "\n\n"
end

# several types are too general to be saved as a record, unless they have GPS info within the bounding box
def confirm_general_type_has_gps(parsed_values)
  if @general_types_array.index(parsed_values["type"])
    if !gps_in_bounding_box([parsed_values["gps_lat"], parsed_values["gps_long"]], @bounding_box) 
      print "GPS for " + parsed_values["type"] + " not in bounding box\n"
      parsed_values["type"] = "Unspecified"
    end
  end
end

#####################################################################################################################
# removing duplicates

def tweetIsSameAs(tweet_new, tweet_old)
  if tweet_old == tweet_new
    return true
  end
  return false
end

# return true if tweet_new is a likely RT of tweet_old
def tweetIsRetweetOf(tweet_new, tweet_old)
  # straight RT with RT at front
  if tweet_new.downcase =~ /rt @([^ ]*)[ ]([^`]*)/
    tweet_compare = $2
    tweet_compare = tweet_compare[0...(tweet_compare.length - 10)]
    
    if tweet_old.downcase.index(tweet_compare)
      return true
    end
    
  end

  return false
end
