require 'sinatra'
require 'date'
require 'pry'
require 'yaml'
require 'uri'
require 'json'
require 'data_mapper'
require 'aws-sdk'
require 'gon-sinatra'

if (File.exists?("config.yml"))
  yml = YAML.load_file("config.yml")
  access_key_id = yml["s3_access_key_id"]
  secret_access_key = yml["s3_secret_access_key"]
  AUTH_USER = yml["username"]
  AUTH_PASSWORD = yml["password"]
else
  access_key_id = ENV["S3_ACCESS_KEY_ID"]
  secret_access_key = ENV["S3_SECRET_ACCESS_KEY"]
  AUTH_USER = ENV["USERNAME"]
  AUTH_PASSWORD = ENV["PASSWORD"]
end

## AWS Set up
Aws.config.update({
    region: 'us-west-2',
    credentials: Aws::Credentials.new(access_key_id, secret_access_key)
})
bucket = 'jfeliz'

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/jfeliz')

class Artist
  include DataMapper::Resource

  property :id,          Serial, :unique => true
  property :name,        String, :required => true, :unique => true, :length => 100
  property :description, Text
  property :url,         Text, :unique => true
  property :private,     Boolean, :default => true
  property :created_at,  DateTime

  has n, :songs, :through => Resource
end

class Song
  include DataMapper::Resource

  property :id,           Serial, :unique => true
  property :name,         String, :required => true, :length => 100
  property :description,  Text
  property :url,          Text, :unique => true
  property :private,      Boolean, :default => true
  property :created_at,   DateTime
  property :recorded_at,  DateTime

  has n, :artists, :through => Resource
end

DataMapper.finalize
### DO NOT AUTO MIGRATE
DataMapper.auto_upgrade!

set :show_exceptions, :after_handler

error do
  '~~~ sorry :| ~~~'
end

not_found do
  '~~~ sorry nothing here ~~~'
end

### NEW ROUTES MORE RESTFUL
#
get '/update-content' do
  protected!

  @songs = Song.all()
  for song in @songs 
    if song.url.include?("jfeliz") && song.url.end_with?(".mp3")
      s3 = Aws::S3.Resource.new(region: 'us-west-1')
      key = song.url.split("jfeliz/")[1]
      object = s3.bucket(bucket).object(key)
      object.content_type = "audio/mpeg"
      object.content_disposition = "attachment; filename=#{@song.name}.mp3"
    end
  end
end

get '/' do
  redirect '/songs'
end

# Get Artists
get '/artists', :provides => ['html', 'json'] do
  try(404) do
    @artists = Artist.all(:order => :created_at.desc)
    if @artists
      @artists.to_json
      erb :artists
    else
      halt 404
    end
  end
end

# Create Artist
post '/artists' do
  content_type :json
  protected!

  try(500) do
    hash_params = hash_from_request(request)
    @artist = Artist.new(hash_params)
    if @artist.save
      @artist.to_json
    else
      halt 500
    end
  end
end

# Get Artist
get '/artists/:id', :provides => ['html', 'json'] do
  try(404) do
    @artist = Artist.get(params[:id].to_i)
    if @artist
      @artist.to_json
      erb :artist
    else
      halt 404
    end
  end
end

# Edit Artist
put '/artists/:id' do
  content_type :json
  protected!

  #get and edit
  try(500) do
    @artist = Artist.get(params[:id].to_i)
    if @artist
      @artist.to_json
    else
      halt 500
    end
  end
end

# Delete Artist
delete '/artists/:id/delete' do
  content_type :json
  protected!

  try(500) do
    @artist = Artist.get(params[:id].to_i)
    if @artist.destroy
      {:success => "ok"}.to_json
    else
      halt 500
    end
  end
end

# Get Song For Artist
get '/artists/:id/songs', :provides => ['html', 'json'] do
  # TODO respect privacy property of songs 
  try(404) do
    @authorized = authorized?
    @artist = Artist.get(params[:id].to_i)
    @songs = @artist.songs(:order => [ :recorded_at.desc, :name.asc ])
    if @songs
      @songs.to_json
      erb :songs
    else
      halt 404
    end
  end
end

# Create Song For Artist
post '/artists/:id/songs' do
  content_type :json
  protected!

  try(500) do
    hash_params = hash_from_request(request)
    hash_params = hash_params.reduce({}) do |memo, (k, v)| 
        memo.merge({ k.to_sym => v})
    end
    file_hash = {}
    if !params["file"].nil?
      file_hash = params["file"].dup
      hash_params.delete(:file)
    end
    @artist = Artist.get(params[:id].to_i)
    hash_params.delete(:id)
    @song = Song.new(hash_params)
    if !file_hash.empty?
      if file_hash[:type] != "audio/mp3"
        puts "invalid audio type expecting audio/mp3 got #{file_hash[:type]}"
        halt 500
      end
      fi_path = parameterize({:artist => @artist.name, :song => @song.name, :id => @song.id}) + ".mp3"
      url = "https://s3.amazonaws.com/jfeliz/music/" + fi_path
      # Handle privacy
      s3 = Aws::S3::Resource.new(region: 'us-west-1')
      s3object = s3.bucket(bucket).object("music/" + fi_path)
      s3object.content_type = "audio/mpeg"
      s3object.content_disposition = "attachment; filename=#{@song.name}.mp3" 
      s3object.upload_file(file_hash[:tempfile], acl: 'public-read')
      @song.url = s3object.public_url
    end
    # Create S3 Url for song
    if settings.development? && @song.url.nil?
      @song.url = "test #{@artist.id} #{@song.name}"
    end
    if @song.save
      @artist.songs << @song
      if @artist.save
        @song.to_json
      else
        puts "artist failed to save"
        puts @artist.errors.each do |e|
          puts e
        end
        halt 500
      end
    else
      @song.errors.each { |e| puts e}
      halt 500
    end
  end
end

# Get Song For Artist
get '/artists/:id/songs/:song_id', :provides => ['html', 'json'] do
  try(404) do
    @artist = Artist.get(params[:id].to_i)
    @artist.songs.each do |song|
      if song.id == params[:song_id].to_i
        @song = song
      end
    end
    if !@song.nil?
      @song.to_json
      erb :song
    else
      halt 404
    end
  end
end

# Edit Song For Artist
put '/artists/:id/songs/:song_id' do
  content_type :json
  protected!
  # TODO
  halt 500
end

# Delete Song For Artist
delete '/artists/:id/songs/:song_id' do
  content_type :json
  protected!

  try(500) do
    @artist = Artist.get(params[:id].to_i)
    @artist.songs.each do |song|
      if song.id == params[:song_id].to_i
        @song = song
        break
      end
    end
    if !@song.url.nil?
      # destroy from s3
      fi_path = parameterize({:artist => @artist.name, :song => @song.name, :id => @song.id}) + ".mp3"
      s3 = Aws::S3::Resource.new(region: 'us-west-1')
      s3object = s3.bucket(bucket).object("music/" + fi_path)
      s3object.delete()
    end
    link = ArtistSong.get(@artist.id, @song.id)
    if link.destroy 
      if @song.artists.empty?
        if @song.destroy
          {:success => "ok"}.to_json
        end
      else
        {:success => "ok"}.to_json
      end
    else
      halt 500
    end
  end
end

# Useful route to Delete Song For Artist w/ Get
get '/artists/:id/songs/:song_id/delete' do
  content_type :json
  protected!

  status, headers, body = call env.merge("PATH_INFO" => "/artists/#{params[:id]}/songs/#{params[:song_id]}", "REQUEST_METHOD" => "DELETE")
  [status, headers, body.map(&:upcase)]
end

# Get Songs
get '/songs', :provides => ['html', 'json'] do
  try(404) do
    # Handle search parameters
    search_options = { :order => [ :recorded_at.desc, :name.asc ] }
    artist_name = params["artist-name"] || ""
    recorded_begin = nil
    if !params["recorded-start"].nil? && !params["recorded-start"].empty?
      search_options[:recorded_at.not] = nil
      recorded_begin = DateTime.parse(params["recorded-start"])
    end
    recorded_end = nil
    if !params["recorded-end"].nil? && !params["recorded-end"].empty?
      recorded_end = DateTime.parse(params["recorded-end"])
    end
    @songs = Song.all(search_options)
    filtered_songs = []
    for song in @songs
      song_name = params["song-name"]
      if song_name != nil && !song_name.empty?
        if song.name.include? song_name
          filtered_songs.push(song)
        end
      end
      artist_names = song.artists.map { |artist| artist.name }
      if !artist_name.empty? && !artist_names.include?(artist_name)
        next
      end
      recorded_at = song.recorded_at
      if recorded_at.nil?
        filtered_songs.push(song)
        next
      end
      if !recorded_begin.nil? && song.recorded_at < recorded_begin
        next
      end
      if !recorded_end.nil? && song.recorded_at > recorded_end
        next
      end
      filtered_songs.push(song)
    end 
    @songs = filtered_songs
    if @songs
      @songs.to_json
      erb :songs
    else
      halt 404
    end
  end
end

# Create Song - Eventually
post '/songs' do
  content_type :json
  protected!
  halt 500
end

# Get Song
get '/songs/:id', :provides => ['html', 'json'] do
  try(404) do
    @song = Song.get(params[:id].to_i)
    if @song
      @song.to_json
      erb :song
    else
      halt 404
    end
  end
end

put '/songs/:id' do
  content_type :json
  protected!

  try(500) do
    hash_params = hash_from_request(request)
    artists = []
    hash_params.keys.each do |key| 
      if key.include?("artist")
        artists.push(hash_params[key])
      end
    end
    hash_params[:artists] = artists
    hash_params = hash_params.reduce({}) do |memo, (k, v)| 
      memo.merge({ k.to_sym => v})
    end

    new_song_name = hash_params[:name] || ""
    new_artists_names = hash_params[:artists]
    @song = Song.get(params[:id].to_i)
    if !hash_params[:recorded_at].nil? && !hash_params[:recorded_at].empty?
      new_date = DateTime.parse(hash_params[:recorded_at])
      @song.recorded_at = new_date
    end
    if !new_song_name.empty?
      @song.name = new_song_name
    end
    for name in new_artists_names
      next if name.nil?
      next if name.empty?
      artist = Artist.first_or_create(:name => name)
      if !@song.artists.include?(artist)
        @song.artists << artist
      end
    end
    if @song.save
      redirect '/songs'
    else
      halt 500
    end
  end
end

# Delete Song
delete '/songs/:id/delete' do
  content_type :json
  protected!

  try(500) do
    @song = Song.get(params[:id].to_i)
    @song.artists.each do |artist|
      fi_path = parameterize({:artist => artist.name, :song => @song.name, :id => @song.id}) + ".mp3"
      s3 = Aws::S3::Resource.new(region: 'us-west-1')
      s3object = s3.bucket(bucket).object("music/" + fi_path)
      s3object.delete()
      link = ArtistSong.get(artist.id, @song.id)
      link.destroy
    end

    if @song.destroy
      {:success => "ok"}.to_json
    else
      halt 500
    end
  end
end

# Get route for Delete Song
get '/songs/:id/delete' do
  content_type :json
  protected!

  status, headers, body = call env.merge("PATH_INFO" => "/songs/#{params[:id]}/delete", "REQUEST_METHOD" => "DELETE")
  [status, headers, body.map(&:upcase)]
end

# Frontend UI For Post / Edit

get '/create_artist' do
  erb :create_artist
end

get '/create_songs' do
  erb :create_songs
end

get '/artists/:id/edit' do
  protected!
  #'ui to edit artist or even delete'
  halt 404
end

get '/songs/:id/edit' do
  protected!
  #'ui to edit song for artist or even delete'
  # should include linking songs to other artists or unlinking
  # ability to modify the song name
  # ability to set the recorded date with useful time picker
  try(400) do
    @song = Song.get(params[:id])
    @artists_name = ""
    @song.artists.each do |artist|
      @artists_name += "#{artist.name} "
    end
    
    if !@song.nil?
      erb :edit_song
    else
      halt 404
    end
  end
end

post '/edit_songs_form/:id' do
  protected!

  status, headers, body = call env.merge("PATH_INFO" => "/songs/#{params[:id]}", "REQUEST_METHOD" => "PUT")
  [status, headers, body.map(&:upcase)]
end

post '/upload_songs_form' do
  protected!

  try(500) do
    artist_name = params["artist"]
    if params["file"][:type] != 'audio/mp3'
      puts 'Incorrect audio type expecting audio/mp3'
      puts 'put received ' + params["file"][:type]
      halt 500
    end
    file_name = params["file"][:filename]
    @artist = Artist.first(:name => artist_name)
    env["rack.request.form_hash"].delete("artist")
    env["rack.request.form_hash"][:id] = @artist.id
    env["rack.request.form_hash"][:name] = file_name[0..-5]
    status, headers, body = call env.merge("PATH_INFO" => "/artists/:#{@artist.id}/songs", "REQUEST_METHOD" => "POST")
    [status, headers, body.map(&:upcase)]
  end
end

get '/search' do
  # ui to search song by day/month/year on recorded at
  try(404) do
    erb :search
  end
end

get '/bbjam' do
  bbjam = ["jess", "joshua", "bryan", "nathaniel"]
  try(404) do
    songs = Song.all(:order => [:recorded_at.desc, :name.asc])
    bbjam_songs = []
    for song in songs
      artists = song.artists.map {|artist| artist.name}
      if song.artists.count > 1 && !(artists & bbjam).empty?
        bbjam_songs.push(song)
      end
    end

    @songs = bbjam_songs
    erb :songs
  end
end

get '/login' do
  protected!

  redirect '/'
end

helpers do
  def parameterize(params)
    URI.escape(params.collect{|k,v| "#{k}=#{v}"}.join('&'))
  end
  
  def hash_from_request(request)
    if request.params.keys.empty?
      # Assuming json body
      json = request.body.read
      JSON.parse(json)
    else
      request.params
    end
  end

  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == [AUTH_USER, AUTH_PASSWORD]
  end

  def try(error_int, &block)
    begin
      block.call
    rescue StandardError => e
      puts e.to_s
      halt error_int
    end
  end
end
