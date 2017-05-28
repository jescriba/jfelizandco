require 'sinatra'
require 'sinatra/contrib'
require 'bcrypt'
require 'date'
require 'pry'
require 'yaml'
require 'uri'
require 'json'
require 'data_mapper'
require 'aws-sdk'
require 'gon-sinatra'
require 'will_paginate'
require 'will_paginate/data_mapper'
require 'resque'

enable :sessions

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
    region: 'us-west-1',
    credentials: Aws::Credentials.new(access_key_id, secret_access_key)
})
bucket = 'jfeliz'

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/jfeliz')

class User
  include DataMapper::Resource

  property :id,          Serial, :unique => true
  property :name,        String, :required => true, :unique => true, :length => 100
  property :description, Text
  property :password,    Text, :required => true
  property :created_at,  DateTime

  # Liked Songs
  has n, :songs, :through => Resource

  self.per_page = 10

  def favorites
    songs
  end
end

class SongUploader
  @queue = :song_upload

  # UploadParams: file_params.merge({ :artist_name => artist_name,
  #                                     :song_name => song_name,
  #                                     :base_url => base_url,
  #                                     :lossy_url => lossy_url,
  #                                     :lossless_url => lossless_url,
  #                                     :is_lossless => lossless_url.empty?
  #                                  })
  def self.perform(upload_params)
    s3 = Aws::S3::Resource.new(region: 'us-west-1')

    extension = upload_params[:filename].strip(".")[1]

    if upload_params[:is_lossless]
      lossless_object_path = upload_params[:lossless_url].chomp(upload_params[:base_url])
      s3_lossless_object = s3.bucket(bucket).object(lossless_object_path)

      # upload
      s3_lossless_object.upload_file(upload_params[:tempfile], acl: 'public-read')
      s3_lossless_object.copy_to("#{s3_lossless_object.bucket.name}/#{s3_lossless_object.key}",
                              :metadata_directive => "REPLACE",
                              :acl => "public-read",
                              :content_type => upload_params[:type],
                              :content_disposition => "attachment; filename='#{upload_params[:song_name]}.#{extension}'")

      # transcode
      lossy_object_path = upload_params[:lossy_url].chomp(upload_params[:base_url])
      s3_lossy_object = s3.bucket(bucket).object(lossy_object_path)

      # upload
      transcoded_file = ""
      s3_lossy_object.upload_file(transcoded_file, acl: 'public-read')
      s3_lossy_object.copy_to("#{s3_lossy_object.bucket.name}/#{s3_lossy_object.key}",
                              :metadata_directive => "REPLACE",
                              :acl => "public-read",
                              :content_type => "audio/mpeg",
                              :content_disposition => "attachment; filename='#{upload_params[:song_name]}.#{extension}'")
    else
      lossy_object_path = upload_params[:lossy_url].chomp(upload_params[:base_url])
      s3_lossy_object = s3.bucket(bucket).object(lossy_object_path)

      # upload
      s3_lossy_object.upload_file(upload_params[:tempfile], acl: 'public-read')
      s3_lossy_object.copy_to("#{s3_lossy_object.bucket.name}/#{s3_lossy_object.key}",
                              :metadata_directive => "REPLACE",
                              :acl => "public-read",
                              :content_type => "audio/mpeg",
                              :content_disposition => "attachment; filename='#{upload_params[:song_name]}.#{extension}'")
    end
  end
end

class Artist
  include DataMapper::Resource

  property :id,          Serial, :unique => true
  property :name,        String, :required => true, :unique => true, :length => 100
  property :description, Text
  property :url,         Text, :unique => true
  property :private,     Boolean, :default => true
  property :created_at,  DateTime

  has n, :songs,  :through => Resource
  has n, :albums, :through => Resource

  self.per_page = 10
end

class Album
  include DataMapper::Resource

  property :id,          Serial, :unique => true
  property :name,        String, :required => true, :unique => true, :length => 100
  property :description, Text
  property :private,     Boolean, :default => true
  property :created_at,  DateTime
  property :released_at, DateTime

  has n, :songs,   :through => Resource
  has n, :artists, :through => Resource

  self.per_page = 10
end

class Song
  include DataMapper::Resource

  property :id,           Serial, :unique => true
  property :name,         String, :required => true, :length => 100
  property :description,  Text
  property :url,          Text, :unique => true
  property :lossless_url, Text, :unique => true
  property :private,      Boolean, :default => true
  property :created_at,   DateTime
  property :recorded_at,  DateTime

  has n, :artists, :through => Resource
  has n, :users,   :through => Resource
  has n, :albums,  :through => Resource

  self.per_page = 10

  def liked_by(user)
    if user
      if users.get(user.id)
        return true
      end
    end

    false
  end

  def likes
    users.count
  end

  def artists_array()
    arr = []
    artists.each do |artist|
      arr.push(artist.attributes)
    end

    arr
  end

  def set_recorded_date
    date_match =  /\d\d-\d\d-\d{4}/.match(self.name)
    if date_match
      begin
        ## Parse in American format mm/dd/yyyy
        self.recorded_at = DateTime.strptime(date_match[0], "%m/%d/%Y")
      rescue ArgumentError
        date_components = date_match[0].split("-")
        self.recorded_at = DateTime.parse(date_components[1] + "-" + date_components[0] + "-" + date_components[2])
      end
    end
  end
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
get '/' do
  redirect '/songs'
end

get '/signup' do
  erb :signup
end

post '/signup' do
  try(500) do
    hash_params = hash_from_request(request)
    crypted_password = BCrypt::Password.create(hash_params["password"])
    @user = User.new("name" => hash_params["username"], "password" => crypted_password)
    if @user.save
      session[:id] = @user.id
      @current_user = @user
      redirect '/songs'
    else
      halt 500
    end
  end
end

get '/login' do
  if session[:id]
    redirect '/logout'
  end
  erb :login
end

post '/login' do
  try(500) do
    hash_params = hash_from_request(request)
    @user = User.first(:name => hash_params["username"])
    if @user
      password = BCrypt::Password.new(@user.password)
      if password == hash_params["password"]
        session[:id] = @user.id
        @current_user = @user
        redirect '/songs'
      else
        # TODO More session error handling
        halt 500
      end
    else
      halt 500
    end
  end
end

get '/logout' do
  erb :logout
end

post '/logout' do
  session.clear
  @current_user = nil
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

# Get Albums
get '/albums', :provides => ['html', 'json'] do
  # TODO
end

# Create Albums
post '/artists' do
  content_type :json
  protected!

  # TODO
end

# Get Album
get '/albums/:id', :provides => ['html', 'json'] do
  # TODO
end

# Edit Album
put '/albums/:id' do
  content_type :json
  protected!

  # TODO
end

# Delete Album
delete '/albums/:id/delete' do
  content_type :json
  protected!

  # TODO
end

# Get Song For Artist
get '/artists/:id/songs', :provides => ['html', 'json'] do
  # TODO respect privacy property of songs
  try(404) do
    @authorized = authorized?
    @current_user = current_user()
    @artist = Artist.get(params[:id].to_i)
    @songs = @artist.songs(:order => [ :recorded_at.desc, :name.asc ]).page(params[:page])
    if @songs
      respond_to do |f|
        f.html { erb :songs }
        f.json do
          songs = []
          @songs.each do |song|
            s = song.attributes
            s[:liked] = song.liked_by(@current_user)
            s[:likes] = song.likes
            s[:artists] = song.artists_array
            songs.push(s)
          end
          songs.to_json
        end
      end
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
    # Parse params
    hash_params = hash_from_request(request)
    file_params = hash_params[:file].dup
    song_name = song_name_from_hash(file_params)
    hash_params.merge!({ :name => song_name }) if song_name
    hash_params.delete(:file)

    # Get Artist
    @artist = Artist.get(hash_params[:id].to_i)
    hash_params.delete(:id)

    # Create Song and Parse Title for date
    @song = Song.new(hash_params)
    @song.set_recorded_date

    # Upload To S3 - Handles [aif, wav, flac, mp3]
    # Lossless formats will transcode to have mp3 and lossless links
    @song.url, @song.lossless_url = upload_song(file_params, @artist.name, @song.name)

    # Save Song
    if @song.save
      @artist.songs << @song
      if @artist.save
        @song.to_json
      else
        @artist.errors.each { |e| puts e }
        halt 500
      end
    else
      @song.errors.each { |e| puts e }
      halt 500
    end
  end
end

# Get Song For Artist
get '/artists/:id/songs/:song_id', :provides => ['html', 'json'] do
  try(404) do
    @current_user = current_user()
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
    @current_user = current_user()

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
    @songs = Song.all(search_options).page(params[:page])
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
      respond_to do |f|
        f.html { erb :songs }
        f.json do
          songs = []
          @songs.each do |song|
            s = song.attributes
            s[:liked] = song.liked_by(@current_user)
            s[:likes] = song.likes
            s[:artists] = song.artists_array
            songs.push(s)
          end
          songs.to_json
        end
      end
    else
      halt 404
    end
  end
end

# Create Song
post '/songs' do
  content_type :json
  protected!

  # TODO
end

# Get Song
get '/songs/:id', :provides => ['html', 'json'] do
  try(404) do
    @current_user = current_user()
    @song = Song.get(params[:id].to_i)
    if @song
      @song.to_json
      erb :song
    else
      halt 404
    end
  end
end

# Route to Un/Favorite songs - just requires user permission
post '/songs/:id/favorite' do
  content_type :json

  try(500) do
    @current_user = current_user()
    return unless @current_user

    hash_params = hash_from_request(request)
    @song = Song.get(hash_params["id"].to_i)
    if @song.liked_by(@current_user)
      link = @song.song_users.first(:user => @current_user)
      link.destroy
    else
      @song.users << @current_user
    end

    if @song.save
      redirect back
    else
      halt 500
    end
  end
end

put '/songs/:id' do
  content_type :json
  protected!

  # TODO Refactor
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
    @artist = Artist.first(:name => artist_name)
    env["rack.request.form_hash"].delete("artist")
    env["rack.request.form_hash"][:id] = @artist.id
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

helpers do
  def current_user()
    if @current_user
      @current_user
    elsif session[:id]
      @current_user = User.get(session[:id])
    end
  end

  def parameterize(params)
    URI.escape(params.collect{|k,v| "#{k}=#{v}"}.join('&'))
  end

  def upload_song(file_params, artist_name, song_name)
    file_type = file_params[:type]
    lossless_formats = ["audio/x-aiff", "audio/aiff", "audio/x-wav", "audio/wav", "audio/flac"]
    lossy_formats = ["audio/mp3", "audio/mpeg"]
    raise "Invalid audio format: #{file_type}" unless (lossless_formats + lossy_formats).include?(file_type)

    base_fi_path = parameterize({ :artist => artist_name, :song => song_name })
    base_folder = settings.development? ? "test" : "jfeliz"
    base_url = "https://s3.amazonaws.com/#{base_folder}/music"
    lossy_url = "#{base_url}/#{base_fi_path}.mp3"
    lossless_url = ""
    if lossless_formats.include?(file_type)
      lossless_url = "#{base_url}/#{base_fi_path}." + file_params[:filename].split(".")[1]
    end

    # Schedule job
    upload_params = file_params.merge({
                                        :artist_name => artist_name,
                                        :song_name => song_name,
                                        :base_url => base_url,
                                        :lossy_url => lossy_url,
                                        :lossless_url => lossless_url,
                                        :is_lossless => lossless_url.empty?
                                     })
    Resque.enqueue(SongUploader, upload_params)

    # Return destination urls
    [lossy_url, lossless_url]
  end

  def song_name_from_hash(file_params)
    return nil unless file_params

    file_name = file_params[:filename]
    return nil unless file_name

    # Strip off extension
    file_name.split(".")[0]
  end

  def hash_from_request(request)
    hash_params = {}
    if request.params.keys.empty?
      # Assuming json body
      json = request.body.read
      hash_params = JSON.parse(json)
    else
      hash_params = request.params
    end

    hash_params = hash_params.reduce({}) do |memo, (k, v)|
        memo.merge({ k.to_sym => v})
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
