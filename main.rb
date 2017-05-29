require_relative 'models/song_uploader'
require_relative 'globals'
require 'sinatra'
require 'sinatra/contrib'
require 'bcrypt'
require 'date'
require 'pry'
require 'uri'
require 'json'
require 'data_mapper'
require 'aws-sdk'
require 'gon-sinatra'
require 'will_paginate'
require 'will_paginate/data_mapper'
require 'resque'
require 'fileutils'

enable :sessions

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

  def lossy_url
    self.url
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

class Main < Sinatra::Base
  include Globals
  register Sinatra::Contrib
  register Gon::Sinatra

  BASE_URL = "https://s3-us-west-1.amazonaws.com/jfeliz/"

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
          puts "ERROR - failed saving artist"
          @artist.errors.each { |e| puts e }
          halt 500
        end
      else
        puts "ERROR - failed saving song"
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
        lossy_url = @song.lossy_url
        lossless_url = @song.lossless_url
        extensions = []
        extensions.push(File.extname(lossless_url)) unless lossless_url.empty?
        extensions.push(File.extname(lossy_url)) unless lossy_url.empty?

        for ext in extensions
          relative_path = "#{relative_s3_path(@artist.name, @song.name, @song.id)}#{ext}"
          s3 = Aws::S3::Resource.new(region: 'us-west-1')
          s3object = s3.bucket(BUCKET).object("music/" + relative_path)
          s3object.delete()
        end
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
        lossy_url = @song.lossy_url
        lossless_url = @song.lossless_url
        extensions = []
        extensions.push(File.extname(lossless_url)) unless lossless_url.empty?
        extensions.push(File.extname(lossy_url)) unless lossy_url.empty?
        for ext in extensions
          relative_path = "#{relative_s3_path(@artist.name, @song.name, @song.id)}#{ext}"
          s3 = Aws::S3::Resource.new(region: 'us-west-1')
          s3object = s3.bucket(BUCKET).object("music/" + relative_path)
          s3object.delete()
        end

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

  get '/artist/create' do
    erb :create_artist
  end

  get '/song/create' do
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

    def relative_s3_path(artist_name, song_name)
      "#{URI.escape(artist_name)}/#{URI.escape(song_name)}"
    end

    def upload_song(file_params, artist_name, song_name)
      file_type = file_params[:type]
      lossless_formats = ["audio/x-aiff", "audio/aiff", "audio/x-wav", "audio/wav", "audio/flac"]
      lossy_formats = ["audio/mp3", "audio/mpeg"]
      raise "Invalid audio format: #{file_type}" unless (lossless_formats + lossy_formats).include?(file_type)

      base_fi_path = relative_s3_path(artist_name, song_name)
      base_folder = settings.development? ? "test/" : ""
      lossy_url = "#{BASE_URL}#{base_folder}music/#{base_fi_path}.mp3"
      lossless_url = ""
      extension = File.extname(file_params[:tempfile])
      if lossless_formats.include?(file_type)
        lossless_url = "#{BASE_URL}#{base_folder}music/#{base_fi_path}#{extension}"
      end

      temp_fi_basename = File.basename(file_params[:tempfile], extension)
      copied_fi_path = "#{Dir.pwd}/tmp/#{temp_fi_basename}-copy#{extension}"
      FileUtils.cp(file_params[:tempfile].path, copied_fi_path)

      # Schedule job
      upload_params = file_params.merge({
                                          :artist_name => artist_name,
                                          :song_name => song_name,
                                          :base_url => BASE_URL,
                                          :lossy_url => lossy_url,
                                          :lossless_url => lossless_url,
                                          :is_lossless => !lossless_url.empty?,
                                          :tempfile_path => copied_fi_path
                                       })
      Resque.enqueue(SongUploader, upload_params)

      # Return public destination urls
      lossy_public_url = public_url(artist_name, song_name, ".mp3", base_folder)
      lossless_public_url = public_url(artist_name, song_name, extension, base_folder)
      [lossy_public_url, lossless_public_url]
    end

    def public_url(artist_name, song_name, extension, base_folder)
      "#{BASE_URL}#{base_folder}music/#{CGI::escape(URI.escape(artist_name))}/#{CGI::escape(URI.escape(song_name))}#{extension}"
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
        puts "###############"
        puts "#### ERROR ####"
        puts "###############"
        puts e.to_s
        halt error_int
      end
    end
  end
end
