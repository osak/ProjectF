#!/usr/bin/env ruby

require 'mongo'

include Mongo

mongo = MongoClient.new
db = mongo.db("project_f")
tweets = db["tweets"]

to_remove = []
urls = tweets.find({text: /https?:\/\//, retweeted_status: {"$exists" => false}})
urls.each do |entry|
  puts entry['text']
  remove = false
  if entry['text'] =~ /t\.co/
    # preserve photo tweets
    if not entry['entities']['urls'].all?{|e| e['expanded_url'] =~ /twitpic|yfrog|pic\.twitter\.com/}
      remove = true
    end
  else
    if not entry['text'] =~ /twitpic|yfrog|pic\.twitter\.com/
      remove = true
    end
  end
  if remove
    to_remove << entry['_id']
  end
end
puts to_remove
puts tweets.remove({"_id" => { "$in" => to_remove}})
