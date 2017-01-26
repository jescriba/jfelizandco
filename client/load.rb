require 'pry'
require 'httparty'
require 'json'
require 'net/http'
require 'uri'
require 'mime/types'

fi = File.new('data.json')
dict = JSON.parse(fi.read)
auth = {:username => "joshua", :password => "test"}

dict.keys.each do |key|
  case key 
  when "create_artists"
    dict[key].each do |artist|
      puts artist.to_json
      r = HTTParty.post("http://localhost:9292/artists", :body => artist.to_json, :headers => { 'WWW-Authenticate' => 'Basic realm="Restricted Area"', 'Content-Type' => 'application/json'}, :basic_auth => auth)
      puts r.code
    end
  when "create_songs"
    dict[key].each do |song|
      puts song.to_json
      r = HTTParty.post("http://localhost:9292/artists/1/songs", :body => song.to_json, :headers => { 'Content-Type' => 'application/json'}, :basic_auth => auth)
      puts r.code
    end
    # Test Edit
    #description = {"description" => "Edited description"}
    #r = HTTParty.put("http://localhost:9292/artists/1/songs/2", :body => description.to_json, :headers => { 'Content-Type' => 'application/json'}, :basic_auth => auth)
  else
    puts "nothing happening for #{key}"
  end
end

# Test Upload Song
# 

uri = URI.parse("http://localhost:9292/artists/1/songs/2")
BOUNDARY = "AaB03x"

header = {"Content-Type" => "multipart/form-data; boundary=#{BOUNDARY}"}
          user = {user: {
                     name: 'Bob',
                                        email: 'bob@example.com'
                      }
                      }
file = "f.mp3"

          # We're going to compile all the parts of the body into an array, then join them into one single string
          # # This method reads the given file into memory all at once, thus it might not work well for large files
post_body = []

# Add the file Data
post_body << "--#{BOUNDARY}\r\n"
post_body << "Content-Disposition: 'form-data'; name=\"user\"; filename=\"#{File.basename(file)}\"\r\n"
post_body << "Content-Type: #{MIME::Types.type_for(file)}\r\n\r\n"
post_body << File.read(file)

# Add the JSON
post_body << "--#{BOUNDARY}\r\n"
post_body << "Content-Disposition: form-data; name=\"user\"\r\n\r\n"
post_body << user.to_json
post_body << "\r\n\r\n--#{BOUNDARY}--\r\n"

# Create the HTTP objects
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Put.new(uri.request_uri, header)
request.body = post_body.join

# Send the request
puts request
response = http.request(request)
puts response
