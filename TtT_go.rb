  #!/usr/bin/env ruby
  # Code by Kate Starbird
  
  
require "rubygems"
require "mysql"
require "date"
require "time"
require "fileutils"
require "google_spreadsheet"

@conf = YAML::load(File.read("config.yml"))

load 'TtT_location_parsing.rb'
load 'TtT_tweet_parsing.rb'
load 'TtT_helpers.rb'
load 'TtT_MySQL_processing.rb'
load 'TtT_config_processing.rb'
load 'TtT_update_google_spreadsheet.rb'

run_TtT_parsing_MySQL_with_Google_Spreadsheet()

#db = set_database(@conf["database_name"])
#update_Google_spreadsheet_from_MySQL(db)

