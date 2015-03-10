require "CSV"
require "net/http"
require "json"
require "cgi"
require "addressable/uri"

#OPTIONS
SEPARATOR = "\t"
CSV_PATH = "./test.csv" #can be set by command line argument as well
ADMIN_COOKIE = "579742449f0af01d5f94826244c96f2c"
HOST = "admin.qa.viglink.com"
ESCAPE_SEQ_FORWARD_SLASH = "%2F"
VALID_URL_TYPES = ["DL", "SL"]
MAX_PHRASE_SIZE = 80

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

    choice = ""
    while choice.length < 1 || !["y", "n"].include?(choice[0].downcase)
      puts "Continue with upload of passing rows? (y)es/(n)o?"
      choice = gets.chomp
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

  valid_dest?(dest) && valid_dest_type?(dest_type) && valid_term?(term)
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


# Request Functions

def format_path(user_id, term)
  path = "/users/" + user_id.to_s + "/ci-terms/" + term.gsub("/", ESCAPE_SEQ_FORWARD_SLASH)

  Addressable::URI.encode_component(path, Addressable::URI::CharacterClasses::QUERY)
end

def make_request(path, payload)
  #Note - if this stops working, use your own vglnk.Agent.q cookie valued
  cookie = CGI::Cookie.new("vglnk.Agent.q", ADMIN_COOKIE)

  req = Net::HTTP::Put.new(path, initheader = { 'Content-Type' => 'application/json'})
  req.body = payload
  req['Cookie'] = cookie.to_s
  response = Net::HTTP.new(HOST).start {|http| http.request(req) }

  puts "Uploaded: " + path + " -- " + response.code.to_s
end


#TODO command line args?
# Process command line arguments
#   i = 0
# while i < ARGV.length
#   case ARGV[i]
#     when "--path"
#       csv_path = ARGV[i + 1]
#     when "--separator"
#       separator = ARGV[i + 1]
#     when "--cookie"
#       admin_cookie = ARGV[i + 1]
#     else
#   end
#
#   i += 1
# end
#

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
