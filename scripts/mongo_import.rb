#!/usr/bin/ruby

require 'json'
require 'mongo'
require 'time'
require 'optparse'

include Mongo

def time_hash(time)
  time.hour*10000 + time.min * 100 + time.sec
end

mongo = MongoClient.new
db = mongo.db("project_f")
tweets = db["tweets"]

Dir.glob("*.js") do |file|
  puts file
  text = File.read(file)
  text.sub!(/^.*$/, "")
  json = JSON.parse(text)
  json.each do |tw|
    created_at = Time.parse(tw["created_at"])
    tw["created_at"] = created_at
    tw["created_at_time"] = time_hash(created_at)
    tweets.insert(tw)
  end
end

