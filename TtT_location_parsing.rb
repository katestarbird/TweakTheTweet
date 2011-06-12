#####################################################################################################################
# TtT_Location_Parsing.rb
# Kate Starbird Jan 21, 2011
# code for Tweak the Tweet location parsing

# uses geokit library
# incorporates lessons learned from deploying TtT in 2010 re: how ppl format location in their tweets

require "rubygems"
require 'geokit'



# need to add something for parsing #loc x between a and b to two records, taking GPS from x at a and x at b
#                                   #loc x from a to b

# taking into account GPS metadata, text_location, RT data - choose "best" GPS coords for information
    # if GPS coords imbedded in text, take those
    # if photo, not RT + metadata GPS, take that
    # else take 1) geokit location 2) metadata (if not RT)
# takes the tweet hash and the parsed_values hash
def parse_location(tweet, parsed_values)

  # if GPS coords imbedded in text, take those
  text_lat = parse_lat(tweet["text"])
  text_long = parse_long(tweet["text"])
  if text_lat != "" && text_long != ""
    print "Has #lat, #long\n"
    return [text_lat, text_long]
  end
  
  text_latlong = parse_lat_long(tweet["text"])
  if text_latlong[0] == ""                        # if lat,long wasn't found, check for alternative style lat/long
    text_latlong = parse_lat_long_alt(tweet["text"])
  end
  if text_latlong[0] != ""
    print "Has lat, long or latE, longS: "
    print text_latlong[0].to_s + "," + text_latlong[1].to_s + "\n"
    return text_latlong
  end
  
  # if photo, not RT + metadata GPS, and GPS is in the bounding box area, take that
  # tweet["meta_gps_lat"] and tweet["meta_gps_long"] are metadata values from Twitter API - for geolocated tweets
  if tweet["meta_gps_lat"] != "" && tweet["type"] == "Unspecified" && tweet["meta_gps_long"] != "" && !is_RT(tweet["text"]) && tweet["photo"] != "" && gps_in_bounding_box([tweet["meta_gps_lat"],tweet["meta_gps_long"]], bounding_box)
    print "Is a pic in the location area\n"
    return [tweet["meta_gps_lat"],tweet["meta_gps_long"]]
  end

  # else take 1) geokit location
  if parsed_values["location"] && parsed_values["location"] != ""
    gps = gps_from_text_location(tweet["text"], parsed_values["location"], @location_array)
    if gps != nil
      print "Found GPS from geokit for " + parsed_values["location"] + ": " + gps[0].to_s + "," + gps[1].to_s + "\n"
     return gps
    end    
  end
 
  # else take 2) metadata (if not RT)
  if !is_RT(tweet["text"]) && gps_in_bounding_box([tweet["meta_gps_lat"],tweet["meta_gps_long"]], @bounding_box)
    print "Taking metadata: " + tweet["meta_gps_lat"] + ", " + tweet["meta_gps_long"] + "\n"
    return tweet["meta_gps_lat"],tweet["meta_gps_long"]
  end
  
  # else return ["",""]
  return ["",""]
  
end


def parse_lat(text)
  if text.downcase =~ /(\#lat )([\-]*[0-9]+.[0-9]+)/
    return $2
  end
  return ""
end

def parse_long(text)
  if text.downcase =~ /(\#long |\#lng |\#lon )([\-]*[0-9]+.[0-9]+)/
    return $2
  end
  return ""
end

def parse_lat_long(text)
  if text.downcase =~ /([\-]*[0-9]+\.[0-9]+),[ ]*([\-]*[0-9]+\.[0-9]+)/
    print "lat long assumes" + text + "\n" + $1 + " " + $2+ "\n"
    return [$1, $2]
  end
  
  if text.downcase =~ /([\-]*[0-9]+\.[0-9]+)[ ]+([\-]*[0-9]+\.[0-9]+)/
    print "lat long assumes" + text + "\n" + $1 + " " + $2+ "\n"
    return [$1, $2]
  end
  
  if text.downcase =~ /([\-]*[0-9]+\.[0-9]+)[ ]*([nsew])[,]*[ ]*([\-]*[0-9]+\.[0-9]+)[ ]*([nsew])/
    lat = $1
    long = $3
    if $2 == "s" || $2 == "w"
      lat = "-" + lat
    end
    
    if $4 == "s" || $4 == "w"
      long = "-" + long
    end
    
    if $2 == "e" || $2 == "w"
      x = long
      long = lat
      lat = x
    end
     
    return [lat, long]
  end
  
  return ["", ""] 
end

def parse_lat_long_alt(text)
  lat = long = ""
  if text.downcase =~ /([0-9]+)[\.\,]([0-9]+)[\'\"]*([ns])/
    minutes = $2.to_f / 60;
    lat = $1.to_f + minutes
    if $3 == "n"
      lat = -lat;
    end
  end
  if text.downcase =~ /([0-9]+)[\.\,]([0-9]+)[\'\"]*([ew])/
    minutes = $2.to_f / 60;
    long = $1.to_f + minutes
    if $3 == "e"
      long = -long;
    end
  end

  return [lat, long]
end


# return true if the text contains any of the hashtags in the list/array
def text_has_one_of_tags(tweet_text, location_taglist)
  location_taglist.each do |tag|
    if tweet_text.downcase.index(tag)
      return true
    end
  end
  return false 
end

def gps_in_bounding_box(gps, bounding_box)
  return false if gps[0] == ""
  if gps[0].to_f > bounding_box[0][0] && gps[0].to_f < bounding_box[1][0] && gps[1].to_f > bounding_box[0][1] && gps[1].to_f < bounding_box[1][1]
    return true
  end
  print "GPS not in bounding box\n"
  return false
end

def geokit_location(loc)  
   print "Sending " + loc + " to Geokit\n"
   gk = Geokit::Geocoders::MultiGeocoder.geocode(loc)
   return [gk.lat.to_s, gk.lng.to_s]  
end

def gps_from_text_location(tweet_text, loc, location_array)
  gps = geokit_location(loc)
  if gps[0] != "" && gps_in_bounding_box(gps, @bounding_box)
    return gps
  end
 
  # if the location can't be found as it, we can add other location names (city or state) and send that to geokit
  location_array.each do |location_entry|
    location_subarray = location_entry[0]
    location_taglist = location_entry[1]
    
    # if the text of the tweet has one tags associated with these areas (this is due to distributed nature of events, dif tags for dif locs)
    if text_has_one_of_tags(tweet_text, location_taglist)
        #loops through the locations associated with this tag - and checks to see if we can find a loc in that area
        location_subarray.each do |extra_loc|
          print "Found hashtag, adding " + extra_loc + "\n"
          gps = geokit_location(loc + ", " + extra_loc)
          if gps[0] != "" && gps_in_bounding_box(gps, @bounding_box)
            return gps 
          end 
        end
    end
     
  end 
  return nil
end
