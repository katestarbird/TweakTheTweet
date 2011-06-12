#####################################################################################################################
# TtT_update_google_spreadsheet.rb
# Kate Starbird Jan 22, 2011
# code for Tweak the Tweet - updating Google Spreadsheet from MySQL database

# for synching records back - have to add a field to records... loaded to spreadsheet
# also have to add something to the DB that prohibits MySQL load and update_spreadsheet from co-occuring

require "rubygems"
require "mysql"
require "date"
require "time"
require "google_spreadsheet"

# takes all of the current records in the MySQL database and updates them to the Google Spreadsheet
def update_Google_spreadsheet_from_MySQL(db)
  # Logs in.
  # You can also use OAuth. See document of GoogleSpreadsheet.login_with_oauth for details.
  
  print "Logging in to Google...\n"
  session = GoogleSpreadsheet.login(@conf['google_name'], @conf['google_password'])
  ws = session.spreadsheet_by_key(@conf['google_spreadsheet_key']).worksheets[0]

  el_num = 1  
  spreadsheet_fields = @conf["spreadsheet_order"].split(", ")
  spreadsheet_fields.each do |field|
    ws[1, el_num] = field
    el_num += 1
  end
  
  res = db.query("SELECT " + @conf["spreadsheet_order"].downcase + " FROM records ORDER BY time DESC")
  row_num = 2
  res.each do |row|
    el_num = 1
    row.each do |element|
      if !element || element.length == 0
        element = 'NA'
      end
      ws[row_num, el_num] = element
      el_num += 1
    end
    row_num += 1
  end

  begin
    print "Updating data to Google Spreadsheet...\n"
    ws.save()
    print "Done\n"
    
  rescue
    print "Some sort of worksheet save error - don't save the date\n"
    @save_error = true
    
  end
end

# part of the code that takes new info from spreadsheet and adds that info the appropriate record
def compare_and_update_record(db, row, id, spreadsheet_fields)
    
  # check to see if the same record exists, using record id
  set_string = ""
  insert_string = ""
  field_string = ""
  i = 0
  spreadsheet_fields.each do |field|
    # exclude time & tweet_author, because these fields can't be changed through the Spreadsheet
    if field != "time" && field != "author" && field != "id"
      set_string += field + " = '" + row[i] + "', "
      insert_string += "'" + row[i] + "', "
      field_string += field + ", "          
    end
    i += 1 
  end
  set_string = set_string[0...set_string.length-2]
  insert_string = insert_string[0...insert_string.length-2]
  field_string = field_string[0...field_string.length-2]
    
  # if can't find a record with the id - then add new record
  res = db.query("SELECT id FROM records WHERE id = '" + id + "'")
  if res == nil || res.fetch_row == nil
    db.query("INSERT INTO records (" + field_string + ") VALUES (" + insert_string + ")")
  else
    # if you find a (MySQL) record with the same id, then update that record info with the spreadsheet info
    db.query("UPDATE records SET " + set_string + " WHERE id = '" + id + "'")
  end
end

# synchs MySQL database with any changes that have been made to the spreadsheet itself (deletions, coordinate adds)
def update_MySQL_from_Google_spreadsheet(db)
   print "Updating database from Spreadsheet - for edited records\n\n"
   
   # Logs in.
  # You can also use OAuth. See document of GoogleSpreadsheet.login_with_oauth for details.
  print "Logging in to Google...\n"
  session = GoogleSpreadsheet.login(@conf['google_name'], @conf['google_password'])

  # https://spreadsheets.google.com/pub?key=0AkuhimfFYZrOdFBrTTlUc1dvRlVySXcwcDRpS2VBWVE&hl=en_GB&output=html
  ws = session.spreadsheet_by_key(@conf['google_spreadsheet_key']).worksheets[0]
  
  print "Updating data from Google Spreadhseet...\n"
                                 
  el_num = 1  # number of current element
  row_num = 2 # start with row 2, because the first row is the title row
 
  found_record = []
  
  spreadsheet_fields = @conf["spreadsheet_order"].downcase.split(", ")
  num_fields = spreadsheet_fields.length

  # while we find another row, we push the info from that row into the found_record_array 
  while ws[row_num, 1] != ""
      row_record = Array.new
      for el_num in (1..num_fields)
        row_record[el_num-1] = ws[row_num, el_num]
        row_record[el_num-1] = "" if row_record[el_num-1] == "NA"
      end
      row_num += 1
      el_num = 0
      
      found_record.push(row_record[spreadsheet_fields.index("id")])
      compare_and_update_record(db, row_record, row_record[spreadsheet_fields.index("id")], spreadsheet_fields)  # compare this record against the record by the same number in the db, and synch
  end
  
  # for the entries where there was no record found on the Google Spreadsheet, delete it from the database
  res = db.query("SELECT id FROM records")
  res.each do |row|
    if !(found_record.index(row[0]))
      print "Delete record " + row[0] + "\n"
      db.query("DELETE FROM records WHERE id = '" + row[0] + "'")
    end
  end
  
  print "Done\n"
 
end

#using the Spreadsheet data - hack to find the last row in the spreadsheet
def find_last_row(ws)
  count = 1
  while count < 100000
    if !ws[count, 1]
      print "Found non existent cell\n"
      return count
    end
    if ws[count, 1] == ""
      print "Found no string value\n"
      return count
    end
    count += 1
  end
  
  return -1
end

# takes all of the current records in the MySQL database and updates them to the Google Spreadsheet
def update_Google_spreadsheet_from_MySQL_2(db)
  # Logs in.
  # You can also use OAuth. See document of GoogleSpreadsheet.login_with_oauth for details.
  
  spreadsheet_fields = @conf["spreadsheet_order"].downcase.split(", ")
  
  print "Logging in to Google...\n"
  session = GoogleSpreadsheet.login(@conf['google_name'], @conf['google_password'])
  
  # change title of spreadsheet to indicate updating
  ss = session.spreadsheet_by_key(@conf['google_spreadsheet_key_backup'])  
  ws = ss.worksheets[0]
  table = ws.tables[0]

  row_num = find_last_row(ws)

  # take only records that are in_SS == 0
  res = db.query("SELECT " + @conf["spreadsheet_order"].downcase + " FROM records WHERE in_SS = '0' ORDER BY time") #maybe time DESC
  res.each do |row|
  # values = {}
  # count = 0
  # spreadsheet_fields.each do |field|
  #   values[field] = row[count]
  #   count += 1
  # end
  # table.add_record(values)
   
    el_num = 1
    row.each do |element|
      if !element || element.length == 0
        element = 'NA'
      end
      ws[row_num, el_num] = element
      el_num += 1
    end
    row_num += 1
  end

  begin
    print "Updating data to Google Spreadsheet_2...\n"
    ws.save()
    # change title back to indicate not updating  
  
    print "Done\n"
    db.query("UPDATE records SET in_SS = '1' WHERE in_SS = '0'")    # set records as in Spreadsheet w/in system
  rescue
    print "Some sort of worksheet save error - don't save the date\n"
    @save_error = true
  end

end

