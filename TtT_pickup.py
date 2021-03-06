#!/usr/bin/env python
# A Twitter stream listener for TweakTheTweet using Tweepy.
# Requires Python 2.6
# Requires Tweepy http://github.com/joshthecoder/tweepy
# http://creativecommons.org/licenses/by-nc-sa/3.0/us/
# Based on: http://github.com/joshthecoder/tweepy-examples
# Modifications by @ayman
# Further modifications by Kate Starbird
 
import time
from getpass import getpass
from textwrap import TextWrapper
import tweepy
import re
import pprint
import MySQLdb
 
# Primary Filter, can be a comma seperated list.
PRIMARY_TRACK_LIST = "#tornado,#mowx,#joplin,#joplintornado,#mohaves,#moneeds"

def get_place(st):
    place = ''
    place_url = ''
    box = []
    if st.place:
        place = 'Place Found'
            
        if "name" in st.place and st.place["name"]:
            place = st.place["name"]
 
        if "full_name" in st.place and st.place["full_name"]:
            place = st.place["full_name"]
            
        if "url" in st.place and st.place["url"]:
            place_url = st.place["url"]
        
        if "bounding_box" in st.place:
            if "coordinates" in st.place["bounding_box"]:
                box = st.place["bounding_box"]["coordinates"]
       
    return place,place_url,box
    
def get_coords(st):
    a = None
    b = None
    if st.geo:
        if st.geo["type"]:
            print '%s' % str(st.geo["type"])
        
        if st.geo["coordinates"] and st.geo["coordinates"][0] and st.geo["coordinates"][1]:
            a = st.geo["coordinates"][0]
            b = st.geo["coordinates"][1]
             
    return a,b


class StreamWatcherListener(tweepy.StreamListener):
    status_wrapper = TextWrapper(width=70,
                                 initial_indent=' ',
                                 subsequent_indent=' ')
 
    def __init__(self, u, p):
        self.auth = tweepy.BasicAuthHandler(username = u,
                                            password = p)
        self.api = tweepy.API(auth_handler = self.auth,
                              secure=True,
                              retry_count=3)
        return
 
    def on_status(self, status):
        global db
        global cursor

        place,url,box = get_place(status)
        lat,long = get_coords(status)
        
        num = 0.0
        lat_num = 0.0
        long_num = 0.0
        if (not lat) and box and len(box) > 0:    
            for coord in box[0]:
                print '%s, ' % coord
                lat_num += float(coord[1])
                long_num += float(coord[0])
                num += 1.0
            if lat_num > 0:
                lat = lat_num / num
                long = long_num / num
        
        if lat and long:
            lat_s = '%f' % lat
            long_s = '%f' % long      
        else:
            lat_s = ''
            long_s = ''
        
        text1 = status.text.replace("'", "")
        text = text1.replace('"', '')
    
        print self.status_wrapper.fill(text)
        print '%s %s via %s #%s\n Lat %s, Long %s, Place %s\n' % (status.author.screen_name,
            status.created_at,
            status.source,
            status.id,
            lat_s, long_s, place)
            
        try:                
            sql = "INSERT INTO tweets (text, author, tweet_id, tweet_source, time, meta_gps_lat, meta_gps_long, place, place_url, bounding_box) VALUES  ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')" % \
                    (text, status.author.screen_name, status.id, status.source, status.created_at, lat_s, long_s, place, url, box)

            try:
                # Execute the SQL command
                cursor.execute(sql)
                # Commit your changes in the database
                db.commit()
                print "Commit"

            except:
                # Rollback in case there is any error
                db.rollback()
                print "Rollback"

        except:
            # Catch any unicode errors while printing to console and
            # just ignore them to avoid breaking application.
            pass
        return
 
    def on_limit(self, track):
        print 'Limit hit! Track = %s' % track
        return
 
    def on_error(self, status_code):
        print 'An error has occured! Status code = %s' % status_code
        return True # keep stream alive
 
    def on_timeout(self):
        print 'Timeout: Snoozing Zzzzzz'
        return
 
def main():   
 
    username = your_Twitter_username
    password = your_Twitter_password

    global db
    global cursor
    
    db = MySQLdb.connect (host = "localhost",
        user = "root",
        passwd = "",
        db = your_database_name,
        charset = "utf8",
        use_unicode = True)
    
    cursor = db.cursor ()
    
    listener = StreamWatcherListener(username, password)
    stream = tweepy.Stream(username,
                           password,
                           listener,
                           timeout = None)
    track_list = [k for k in PRIMARY_TRACK_LIST.split(',')]
    stream.filter(track = track_list)
 
if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        cursor.close()
        db.close()
        print '\nCiao!'
