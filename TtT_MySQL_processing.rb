#####################################################################################################################
# TtT_MySQL_processing.rb
# Kate Starbird Jan 21, 2011
# code for Tweak the Tweet - handling MySQL database storage - loading new tweet, parsing them, storing them
# time change happens between tweet and record (not on the tweet, or the last parsed)

require "rubygems"
require "mysql"
require "date"
require "time"

# open the MySQL database and return the pointer to that
def set_database(db_name)
  db = Mysql.init
  db.options(Mysql::SET_CHARSET_NAME, "utf8")
  db.real_connect("localhost", "root", "", db_name)
  return db
end

# return true if this is a new record, false if not
# still working out how to best do this
# simple compare to see if it's a RT of other record
def is_new_record_MySQL(db, tweet, parsed_values)  
  res = db.query("SELECT id, text, time, type, report, gps_lat, gps_long FROM records")
  res.each do |row|
    return false if tweetIsSameAs(tweet["text"], row[1])
    return false if tweetIsRetweetOf(tweet["text"], row[1])
    
    # other tweet compare
    
  end

  return true
end

# store the tweet/record as a record in the database
def store_tweet_MySQL(db, tweet, parsed_values)
  
  cats_string = ""
  values_string = ""
  
  # add all of the tweet attributes
  tweet.each_pair do |cat, value|
    cats_string += cat + "," if cat != "id"
    values_string += "'" + value.to_s + "'," if cat != "id"
  end
  
  # add all of the parsed_values
  parsed_values.each_pair do |cat, value|
    cats_string += cat + "," if cat != "id"
    values_string += "'" + value.to_s + "'," if cat != "id"
  end

  cats_string = cats_string[0...cats_string.length - 1]
  values_string = values_string[0...values_string.length - 1]
  
  # store in the database
  db.query("INSERT INTO records (" + cats_string + ") VALUES (" + values_string + ")")
end

# parse all the tweets since last time parsed - place TtT tweets into records - store
def parse_recent_tweets_MySQL(db, since_time)
  
  # get structure of the tweets table (just in case that changes)
  # should include: id (internal), text, author, tweet_id, time, gps_lat, gps_long, place, place_url, bounding_box  
  tweet_fields = []
  res = db.query("DESCRIBE tweets")
  res.each do |r|
    tweet_fields.push(r[0])
  end

  # go get all tweets since last parsed
  res = db.query("SELECT * FROM tweets WHERE time >= '" + since_time.to_s + "' ORDER BY time")
  res.each do |row|
    # place field info into a tweet hash    
    tweet = Hash.new
    for i in (0...row.length)
      row[i] = "" if row[i] == nil || row[i] == "NULL"
      tweet[tweet_fields[i]] = row[i]
    end
    
    # escape chars that drive MySQL mad
    tweet["text"].gsub!("'", "")
    tweet["text"].gsub!('"', '')

    # if we haven't processed this exact same tweet before - time saver
    #if !tweet_processed_MySQL(db, tweet["text"])  # tag this out
    
      # if the tweet is TtT
      if isTtT(tweet["text"])
        parsed_values = parse_tweet(tweet["text"])
        gps_coords = parse_location(tweet, parsed_values)
        parsed_values["gps_lat"] = gps_coords[0]
        parsed_values["gps_long"] = gps_coords[1]
        
        print parsed_values["type"] + "\n"
        confirm_general_type_has_gps(parsed_values)
        
        # if the tweet is a new record, store it in the database
        if parsed_values["type"] != "Unspecified" && is_new_record_MySQL(db, tweet, parsed_values)
          tweet["time"] = fix_record_time_to_local(tweet["time"], @conf["local_time_offset"].to_f)
          store_tweet_MySQL(db, tweet, parsed_values)
          print "Storing Tweet: " + tweet["text"] + "\n\n"
        end
      end
    #end #tag this out
    
    begin
      db.query("INSERT INTO tweets_processed (text) VALUES ('" + tweet["text"] + "')")     # store that we've processed this exact text before - saves time later 
    rescue
      print "MySQL insert error on " + tweet["text"] + "\n"
    end
  end     
end

# return true if this tweet has already been processed (MySQL)
def tweet_processed_MySQL(db, tweet_text)
  res = db.query("SELECT id FROM tweets_processed WHERE text LIKE '%" + tweet_text + "%'")
  row = res.fetch_row
  return true if row && row[0]
  return false
end

# add the local time offset to the record time for storage
def fix_record_time_to_local(old_time, offset)
  old_time = DateTime.parse(old_time)
  time = (old_time + offset / 24.0).to_s    # this makes local time
  time = time[0...time.length - 6]
  time[10] = " "
  
  return time
end

# get time of last_parsed - port to database portion of code
def time_of_last_parsed(db, parsed_field)
  res = db.query("SELECT time, id FROM " + parsed_field + " ORDER BY time DESC LIMIT 1")
  arow = res.fetch_row
  a_time = arow[0]
  return(DateTime.parse(a_time))
end

# continual grab new, update records
def run_TtT_parsing_MySQL()
  db = set_database(@conf["database_name"])
  since_time = time_of_last_parsed(db, "last_parsed")

  while (true) do
    # get the current time, print in local, convert to GMT for Twitter synching
    time = DateTime.now
    print "* Parse time, local: " + time.to_s + "\n" 
    current_time = time.new_offset(0)

    parse_recent_tweets_MySQL(db, since_time)
    
    since_time = current_time
    db.query("INSERT INTO last_parsed (time) VALUES ('" + current_time.to_s + "')")
    
    sleep @conf["sleep_duration"].to_i
  end
end

# continual grab new, update records
def run_TtT_parsing_MySQL_with_Google_Spreadsheet()
  db = set_database(@conf["database_name"])
  since_time = time_of_last_parsed(db, "last_parsed")

  while (true) do

    # synch MySQL database with google spreadsheet
  #  update_MySQL_from_Google_spreadsheet(db)
    
    # get the current time, print in local, convert to GMT for Twitter synching
    time = DateTime.now
    print "* Parse time, developer local time: " + time.to_s + "\n"
    current_time = time.new_offset(0)
    print " GMT time: " + current_time.to_s + "\n"

    parse_recent_tweets_MySQL(db, since_time)
    
    if @conf['google_spreadsheet_key'] && @conf['google_spreadsheet_key'] != ""
      # update the volunteer Google spreadsheet from the MySQL database - may be future only version
      update_Google_spreadsheet_from_MySQL_2(db)    
    end
    
    # update the Google spreadsheet from the MySQL database
    update_Google_spreadsheet_from_MySQL(db)
    
    since_time = current_time
    db.query("INSERT INTO last_parsed (time) VALUES ('" + current_time.to_s + "')")
    
    sleep @conf["sleep_duration"].to_i
  end
end
