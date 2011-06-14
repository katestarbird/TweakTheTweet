#####################################################################################################################
# TtT_create_database.rb
# Kate Starbird Jan 21, 2011
# Create a TtT database from config file
# database must be created already, this just fills in the structure necessary for parsing

# all tables need to have id set to auto-increment with a primary key

require "rubygems"
require "mysql"
require "date"
require "time"

@conf = YAML::load(File.read("config.yml"))

load '../TtT_config_processing.rb'
load '../TtT_MySQL_processing.rb'

# process the tweet table string into an array of arrays .... [field, type, size]
def process_table(table_string)
  tweet_table_array = []
  
  table_string = table_string[7...table_string.length-1]    # takes of the front FIELD [ and the last ]
  field_array = table_string.split("]; FIELD [")

  field_array.each do |field_string|
    field = field_string.split(",")
    tweet_table_array.push([field[0],field[1],field[2]])
  end
  
  return tweet_table_array
end

# create the tweet table and add all of the fields from the tweet_table_array
def create_tweet_table(db, tweet_table_array)
  structure_string = "id int NOT NULL AUTO_INCREMENT, "
  
  tweet_table_array.each do |field_array|
    structure_string += field_array[0] + "\t" + field_array[1]
    structure_string += "(" + field_array[2] + ")" if field_array[2]
    structure_string += ", "
  end
  
  structure_string += "PRIMARY KEY (id)"
  
  db.query("CREATE TABLE tweets (" + structure_string + ")")

end

# create the record table and add all of the fields from the record_table_array, the tweet_table_array (not id), and all 2ndary tag categories
def create_record_table(db, record_table_array, tweet_table_array)
  structure_string = "id int NOT NULL AUTO_INCREMENT, "

  record_table_array.each do |field_array|
    structure_string += field_array[0] + "\t" + field_array[1]
    structure_string += "(" + field_array[2] + ")" if field_array[2]
    structure_string += ", "
  end  
  
  tweet_table_array.each do |field_array|
    structure_string += field_array[0] + "\t" + field_array[1]
    structure_string += "(" + field_array[2] + ")" if field_array[2]
    structure_string += ", "
  end
  
  @secondary_hash.each_key do |category|
    structure_string += category + "\tvarchar(80), "
  end

  # add in_SS field to records - with default = 0 - might need to adjust this a bit
  structure_string += "in_SS tinyint DEFAULT 0,"
  
  structure_string += "PRIMARY KEY (id)"
  
  db.query("CREATE TABLE records (" + structure_string + ")")

end


db = set_database(@conf["database_name"])
tweet_table_string = @conf["database_tweets_table_structure"]
tweet_table_array = process_table(tweet_table_string)

record_table_string = @conf["database_records_table_structure"]
record_table_array = process_table(record_table_string)

create_tweet_table(db, tweet_table_array)
create_record_table(db, record_table_array, tweet_table_array)
db.query("CREATE TABLE last_parsed ( id int NOT NULL AUTO_INCREMENT, time datetime, PRIMARY KEY (id) )")
db.query("CREATE TABLE last_parsed_RSS ( id int NOT NULL AUTO_INCREMENT, time datetime, PRIMARY KEY (id) )")
db.query("CREATE TABLE last_parsed_KML ( id int NOT NULL AUTO_INCREMENT, time datetime, PRIMARY KEY (id) )")
db.query("CREATE TABLE tweets_processed ( id int NOT NULL AUTO_INCREMENT, text varchar(200), PRIMARY KEY (id) )")

db.query("INSERT INTO last_parsed (id, time) VALUES ('1', '2011-01-01 00:00:00')")
db.query("INSERT INTO last_parsed_RSS (id, time) VALUES ('1', '2011-01-01 00:00:00')")
db.query("INSERT INTO last_parsed_KML (id, time) VALUES ('1', '2011-01-01 00:00:00')")

db.query("CREATE TABLE login_specs ( id int NOT NULL AUTO_INCREMENT, server varchar(100), username varchar(100), password varchar(100), type varchar(100), PRIMARY KEY (id) )")

db.query("ALTER TABLE tweets CONVERT TO CHARACTER SET utf8 COLLATE utf8_general_ci")

