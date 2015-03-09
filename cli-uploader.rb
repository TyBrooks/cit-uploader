require "CSV"
require "net/http"
require "json"
require "cgi"
require "addressable/uri"

#OPTIONS
SEPARATOR = "\t"
FILE_NAME = "./test.csv"
ADMIN_COOKIE = "579742449f0af01d5f94826244c96f2c"

def parse_csv(csv_path)
  csv_opts = {
    :col_sep => SEPARATOR
  }

  data = {}

  CSV.foreach(csv_path, csv_opts) do |row|
    unless valid_row?(row)
      puts "Row Failing Validation: " + row.to_s

      next
    end

    user_id = row[0]
    dest_type = row[1]
    term = row[2].strip
    dest = row[3].strip
    country = row[4]

    unless data.has_key?( user_id )
      data[user_id] = {}
    end

    unless data[user_id].has_key?(term)
      data[user_id][term] = []
    end

    destination = {
      :url => dest,
      :type => dest_type,
      :country => country
    }

    data[user_id][term].push(destination)
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
  valid_types = ["DL", "SL"]

  is_valid = valid_types.include?(type)

  puts "Validation Error: Invalid destination type (must be deep link or search link)" unless is_valid

  is_valid
end

def valid_term?(term)
  p term
  is_valid = term.length <= 80

  puts "Validation Error: Phrase length must be less than 80 characters" unless is_valid

  is_valid
end


# Request Functions

def format_path(user_id, term)
  path = "/users/" + user_id.to_s + "/ci-terms/" + term.gsub("/", "%2F")

  Addressable::URI.encode_component(path, Addressable::URI::CharacterClasses::QUERY)
end

def make_request(path, payload)
  host = "admin.qa.viglink.com"

  #Note - if this stops working, use your own vglnk.Agent.q cookie valued
  cookie = CGI::Cookie.new("vglnk.Agent.q", ADMIN_COOKIE)

  req = Net::HTTP::Put.new(path, initheader = { 'Content-Type' => 'application/json'})
  req.body = payload
  req['Cookie'] = cookie.to_s
  response = Net::HTTP.new(host).start {|http| http.request(req) }
  puts "Uploaded: " + path + " -- " + response.code.to_s
end


# Begin Program

data = parse_csv(FILE_NAME)

data.keys.each do |user_id|
  data[user_id].keys.each do |term|
    path = format_path(user_id, term)

    body = {
      dest: data[user_id][term]
    }.to_json

    make_request(path, body)
  end
end
