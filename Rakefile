require 'data_mapper'
require 'pg'

task :create_db do
  conn = PG.connect(dbname: 'postgres')
  conn.exec("CREATE DATABASE jfeliz")
  DataMapper.auto_migrate!
  puts "Created the jfeliz DB and auto-migrated"
end
