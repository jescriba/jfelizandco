require 'aws-sdk'
require 'yaml'

module Globals
  ## AWS and Globals Set up
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

  if ENV["RACK_ENV"] != 'production'
    Resque.redis = 'localhost:6379'
  else
    puts "Setting global redis url: #{ENV["REDISTOGO_URL"]}"
    uri = URI.parse(ENV["REDISTOGO_URL"])
    Resque.redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  end


  Aws.config.update({
      region: 'us-west-1',
      credentials: Aws::Credentials.new(access_key_id, secret_access_key)
  })

  BUCKET = 'jfeliz'
end
