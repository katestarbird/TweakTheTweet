#####################################################################################################################
# TtT_Tweet_Parsing.rb
# Kate Starbird Jan 21, 2011
# code for Tweak the Tweet parsing

# simple parsing of TtT tweet tags into records - stored and returned in a hash

require "rubygems"

# parses a tweet into a tweet_value_hash, paired by Hash[category of tag] = value
def parse_tweet(tweet_text)

  tweet_value_hash = Hash.new

  # parse primary tag, report, photo, video
  tweet_value_hash["type"] = parse_type(tweet_text)        # parse the tweet type (primary tag)
  tweet_value_hash["report"] = parse_report(tweet_text, tweet_value_hash["type"])    # parse the tweet "report" the info after the primary tag
  tweet_value_hash["photo"] = parse_photo(tweet_text)
  tweet_value_hash["video"] = parse_video(tweet_text)
  
  # if there is no type, we can assume that it is a photo or a video, check that and assign type from those
  if tweet_value_hash["type"] == "Unspecified"
    if tweet_value_hash["photo"] != ""
      tweet_value_hash["type"] = "#photo"
    elsif tweet_value_hash["video"] != ""
      tweet_value_hash["type"] = "#video"
    end
  end

  # parse secondary tags
  secondary_tag_hash = parse_secondary_tags(tweet_text)    # parse on the secondary tags
  tweet_value_hash.merge!(secondary_tag_hash)
  
  return tweet_value_hash
end


# using list of primary tags (ordered from most specific to most general)
# return first tag found
def parse_type(text)
  @primary_tags_array.each do |tag|
    if text.downcase.index(tag)
      return tag.downcase.strip
    end
  end
  return "Unspecified"
end

# parse the text after the type - which is the report
def parse_report(text, type)   
  return "" if type == ""
  
  start_index = text.downcase.index(type)
  return "" if !start_index
  start_index += type.length
  end_index = text.index("#", start_index)
  
  # if no # is found, then use the end of the tweet
  if !end_index
    end_index = text.length
  end
  
  return text[start_index...end_index].strip
end

def parse_RT(text)  
  if text.downcase =~ /(r @|rt @|via @)/
    return true
  end
  return false
end

def parse_photo(text) 
  if text.downcase =~ @photo_reg_ex
    link = "http://" + $2 + $3
    return link
  end
  return ""
end

def parse_video(text) 
  if text.downcase =~ @video_reg_ex
    link = "http://" + $2 + $3
    return link
  end
  return ""
end

# loops through secondary value tags
# creates an array with values associated with those tags
# returns array [category, value],[category, value] - could be a hash
def parse_secondary_tags(text)
  secondary_values_hash = Hash.new
  
  # [category, [tag, tag, tag]], [category, [tag, tag, tag]]
  @secondary_hash.each_pair do |category, tags|         # loop through tags - check text for each tag
    value = ""
    tags.each do |tag|
      start_index = text.downcase.index(tag)
      if start_index
        start_index += tag.length
        end_index = text.index("#", start_index)
        end_index2 = text.downcase.index("ww ", start_index)     # going to include Weather reports' format for locations
        if !end_index
          end_index = text.length
        end
        if end_index2 && end_index2 < end_index       # tests to see if we found one of weather report's locations
          end_index = end_index2
        end
        found = true
        value += text[start_index...end_index].strip
        if value == ""                                      # when the tweet has the secondary tag, but no text after - for something like #confirmed
          print "No value for tag " + tag + "\n"
          value = tag                               # set the value = to the tag, so #confirmed or #unconfirmed
        end    
        value += " / "      # if has multiple 2ndary tags from list, append values to entry
      end
    end
    value = value[0...value.length-3]
    secondary_values_hash[category] = value
  end
  
  return secondary_values_hash
end