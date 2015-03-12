require "CSV"
require "net/http"
require "json"
require "cgi"

#OPTIONS
SEPARATOR = "\t" # CSV separator (by default we're expecting Tab separated values)
CSV_PATH = "./data.csv" #can be set by command line argument as well
VALID_URL_TYPES = ["DL", "SL"] # Currently supports deep links and search links only
MAX_PHRASE_SIZE = 80 # max size of terms

USE_QA = true # whether to use production or qa settings below
#Production settings
HOST = "admin.viglink.com"
COOKIE_NAME = "vglnk.Agent.p"
COOKIE_VALUE = "d9e2f09a7d941d06475de57eca5d874f"
#QA settings
QA_HOST = "admin.qa.viglink.com"
QA_COOKIE_NAME = "vglnk.Agent.q"
QA_COOKIE_VALUE = "579742449f0af01d5f94826244c96f2c"

class String
  def is_integer?
    self.to_i.to_s == self
  end
end

def parse_csv(csv_path)
  csv_opts = {
    :col_sep => SEPARATOR
  }

  data = {}

  row_index = 0
  error_rows = []

  CSV.foreach(csv_path, csv_opts) do |row|
    row_index += 1
    unless valid_row?(row)
      puts "Row Failing Validation: " + row_index.to_s
      puts row.to_s
      puts

      error_rows.push(row_index)
      next
    end

    user_id = row[0]
    dest_type = row[1]
    term = row[2].strip
    dest = row[3].strip
    country = row[4]

    data[user_id] = {} unless data.has_key?( user_id )
    data[user_id][term] = [] unless data[user_id].has_key?( term )

    destination = {
      :url => dest,
      :type => dest_type,
      :country => country
    }

    data[user_id][term].push(destination)
  end

  #error handling
  num_errors = error_rows.length
  if num_errors != 0
    puts "Your CSV had " + num_errors.to_s + " rows that failed validation."
    puts "Row errors: " + error_rows.to_s

    choice = nil
    while choice.nil? || choice.length < 1 || !["y", "n"].include?(choice[0].downcase)
      puts "Continue with upload of passing rows? (y)es/(n)o?"
      choice = STDIN.gets.chomp
    end

    if choice == "n"
      abort("CSV Error -- User aborted")
    end
  end

  data

end

# Validation Functions

def valid_row?(row)
  dest = row[3].strip
  dest_type = row[1]
  term = row[2].strip
  user_id = row[0].strip

  valid_dest?(dest) && valid_dest_type?(dest_type) && valid_term?(term) && valid_user_id?(user_id)
end

def valid_dest?(url)
  is_valid = /^https?\:\/\// =~ url
  puts "Validation Error: Url doesn't begin with http or https!" unless is_valid

  is_valid
end

def valid_dest_type?(type)
  is_valid = VALID_URL_TYPES.include?(type)
  puts "Validation Error: Invalid destination type (must be deep link or search link)" unless is_valid

  is_valid
end

def valid_term?(term)
  is_valid = term.length <= MAX_PHRASE_SIZE
  puts "Validation Error: Phrase length must be less than 80 characters" unless is_valid

  is_valid
end

def valid_user_id?(user_id)
  is_valid = user_id.is_integer?
  puts "Validation Error: user_id is not integer" unless is_valid

  is_valid
end


# Request Functions

def format_path(user_id, term)
  term_escaped = term.split(" ").map{ |word| CGI.escape(word) }.join("%20")
  "/users/" + user_id.to_s + "/ci-terms/" + term_escaped
end

def make_request(path, payload)
  #Note - if this stops working, use your own vglnk.Agent.q cookie valued
  cookie_name = ( USE_QA ) ? QA_COOKIE_NAME : COOKIE_NAME
  cookie_value = ( USE_QA ) ? QA_COOKIE_VALUE : COOKIE_VALUE
  host = ( USE_QA ) ? QA_HOST : HOST

  cookie = CGI::Cookie.new( cookie_name, cookie_value )

  req = Net::HTTP::Put.new( path, initheader = { 'Content-Type' => 'application/json'})
  req.body = payload
  req['Cookie'] = cookie.to_s
  response = Net::HTTP.new( host ).start { |http| http.request(req) }

  puts "Uploaded: " + path + " -- " + response.code.to_s
end

csv_path = CSV_PATH
csv_path = ARGV[0] if ARGV.length == 1

# Begin Program

data = parse_csv(csv_path)

data.keys.each do |user_id|
  data[user_id].keys.each do |term|
    path = format_path(user_id, term)

    body = {
      dest: data[user_id][term]
    }.to_json

    make_request(path, body)
  end
end
