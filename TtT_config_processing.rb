#####################################################################################################################
# config file processing

# this function reads the config file's location string into an array of entrys for [locations],[tags] (could be a hash, but it isn't)
# [[list of location names], [list of #tags associated with those names]] = entry, array = [entry, entry, etc.]
def createLocationArrayFromConfigString(config_location_string)
  location_array = []
  
  entry_array = config_location_string.split("; ")
  
  entry_array.each do |entry|
    entry_split = entry.split("] TAGS [")
    
    loc_list = []
    tag_list = []
    
    locations_string = entry_split[0][12...entry_split[0].length]
    locations = locations_string.split('","')
    locations.each do |location|
      location.gsub!('"', '')
      loc_list.push(location)
    end
    
    tags_string = entry_split[1][0...entry_split[1].length - 1]
    tags = tags_string.split('","')
    tags.each do |tag|
      tag.gsub!('"','')
      tag_list.push(tag)
    end
    
    location_array.push([loc_list, tag_list])
  end
  return location_array
end

# this function reads the config file's secondary_tags string into a hash of category - [tags]
# hash[category] = [list of #tags associated with those names]] 
def createSecondaryHashFromConfigString(secondary_tag_string)
  secondary_hash = Hash.new
  
  entry_array = secondary_tag_string.split("; ")
  
  entry_array.each do |entry|
    entry_split = entry.split('" TAGS [')
    
    tag_list = []
    
    category_string = entry_split[0][10...entry_split[0].length]
    
    tags_string = entry_split[1][0...entry_split[1].length - 1]
    tags = tags_string.split('","')
    tags.each do |tag|
#      tag.strip!
      tag.gsub!('"','')
      tag_list.push(tag)
    end
    
    secondary_hash[category_string] = tag_list
  end
  return secondary_hash
end

# this function reads the config file's bounding_box string into an array of two entrys for lat/long
# [[bottom left lat, long], [top right lat, long]]
def createBoundingBoxFromConfigString(config_bounding_box)
  coord_array = []
  
  coords = config_bounding_box.split(";")
  coords.each do |latlong|
    latlong_array = latlong.split(",")
    coord_array.push([latlong_array[0].to_f,latlong_array[1].to_f])
  end
  return coord_array
end

# this function creates a reg ex from all the TtT-identifier terms + photos + videos
def createTtTRegEx()
  reg_string = ""
  @TtT_identifiers_array.each do |term| 
    reg_string += term + "|"
  end
  @photo_identifiers_array.each do |term| 
    reg_string += term + "|"
  end
  @video_identifiers_array.each do |term| 
    reg_string += term + "|"
  end
  reg_string[reg_string.length-1] = ""
  return Regexp.new(reg_string)
end

# this function creates a reg ex from all the TtT-identifier terms + photos + videos
def createPhotoRegEx()
  reg_string = ""
  @photo_identifiers_array.each do |term| 
    reg_string += term + "|"
  end
  reg_string[reg_string.length-1] = ""
  reg_string = "(http:\/\/)(" + reg_string + ")([^#^ ]*)"
  return Regexp.new(reg_string)
end

# this function creates a reg ex from all the TtT-identifier terms + photos + videos
def createVideoRegEx()
  reg_string = ""
  @video_identifiers_array.each do |term| 
    reg_string += term + "|"
  end
  reg_string[reg_string.length-1] = ""
  reg_string = "(http:\/\/)(" + reg_string + ")([^#^ ]*)"
  return Regexp.new(reg_string)
end

location_string = @conf['add_location_text']
@location_array = createLocationArrayFromConfigString(location_string)
# [[list of location names], [list of #tags associated with those names]] = entry, array = [entry, entry, etc.]

bounding_box_string = @conf['bounding_box']
@bounding_box = createBoundingBoxFromConfigString(bounding_box_string)
# [[bottom left lat, long], [top right lat, long]]

general_types_string = @conf['general_types']
@general_types_array = general_types_string.split(",")
# list of general terms, so tweet must have location info plus this tag to be stored

TtT_identifiers_string = @conf['TtT_identifiers']
@TtT_identifiers_array = TtT_identifiers_string.split(",")
# list of terms/tags that we use to identify a tweet as TtT

photo_identifiers_string = @conf['photo_types']
@photo_identifiers_array = photo_identifiers_string.split(",")
# list of known photo type links

video_identifiers_string = @conf['video_types']
@video_identifiers_array = video_identifiers_string.split(",")
# list of known video type links

primary_tags_string = @conf['primary_tags']
@primary_tags_array = primary_tags_string.split(",")
# list of all primary tags, ordered from most specific to most general (or most likely to be noise)

# tags secondary_tags string from config file, creates a hash where hash[category] = [tag,tag,tag...]
secondary_tag_string = @conf['secondary_tags']
@secondary_hash = createSecondaryHashFromConfigString(secondary_tag_string)

# create reg ex from TtT_identifiers, photo identifiers, and video
@TtT_filter_reg_ex = createTtTRegEx()

# create the photo regex and the video regex for filtering / parsing
@photo_reg_ex = createPhotoRegEx()
@video_reg_ex = createVideoRegEx()

@RSS_feed = @conf['RSS_feed']
@KML_feed = @conf['KML_feed']
