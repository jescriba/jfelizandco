require 'data_mapper'
require 'pg'

task :create_db do
  if ENV["RACK_ENV"] != "production"
    conn = PG.connect(dbname: 'postgres')
    conn.exec("CREATE DATABASE jfeliz")
    DataMapper.auto_migrate!
    puts "Created the jfeliz DB and auto-migrated"
  else
    puts "Skipped auto_migration - in production env"
  end
end
