require 'resque/server'
require_relative 'main'
require_relative 'globals'

$stdout.sync = true

map "/resque" do
  Resque::Server.use Rack::Auth::Basic do |username, password|
    [username, password] == [Globals::AUTH_USER, Globals::AUTH_PASSWORD]
  end

  run Resque::Server
end

map "/" do
  run Main
end
