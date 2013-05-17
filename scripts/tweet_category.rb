#!/usr/bin/env ruby

require 'wordnet-ja'
require 'active_record'
require 'MeCab'
require 'mongo'
require 'parallel'

include Mongo

POS_TABLE = {
  '名詞' => 'n',
  '動詞' => 'v',
  '形容詞' => 'a',
  '副詞' => 'r',
}.freeze

mongo = MongoClient.new
db = mongo.db("project_f")
tweets = db["tweets"]
tagged_tweets = db["tagged_tweets"]

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: File.expand_path('~/app/wnjpn.db'))
Parallel.each(tweets.find, in_processes: 8) do |tweet|
  puts tweet['text']
  id = tweet['_id']
  tagger = MeCab::Tagger.new
  node = tagger.parseToNode(tweet['text'])
  while node
    unless node.surface.empty?
      features = node.feature.split(/,/)
      pos = POS_TABLE[features[0]]
      word = Word.find_by(lemma: node.surface, pos: pos)
      if word
        tags = []
        sense = word.senses.first
        synset = sense.synsets.first
        tags << synset.synset
        ancestors = synset.ancestors
        if ancestors
          ancestors.each do |ancestor|
            tags << ancestor.synset2
          end
        end
        tags.uniq.each do |tag|
          tagged_tweets.insert({obj_id: id, tag: tag})
        end
      end
    end
    node = node.next
  end
end
