#-*- encoding: utf-8 -*-
require 'mongo'
require 'mecab/ext'
require 'wordnet-ja'
require File.join(__dir__, "fatedb.rb")

module ProjectF
  class Fate
    POS_TABLE = {
      '名詞' => 'n',
      '動詞' => 'v',
      '形容詞' => 'a',
      '副詞' => 'r',
    }.freeze

    def initialize(db)
      @db = db
    end

    # Hash the time into single integer
    #
    # @param time [Time] time to be hashed
    # @return [Integer] hashed value
    def time_hash(time)
      time.hour*10000 + time.min*100 + time.sec
    end

    # Make condition object for MongoDB, requesting for the tweets around specified time
    #
    # @param now [Time]
    # @return [Hash] condition hash for MongoDB
    def make_time_cond(now)
      start = self.time_hash(now-1800)
      last = self.time_hash(now+1800)
      if last < start # may be across 00:00
        {"$or" => [
          {created_at_time: {
            "$gt" => start,
            "$lt" => 235959
          }},
          {created_at_time: {
            "$gt" => 000000,
            "$lt" => last
          }}
        ]}
      else
        {created_at_time: {
          "$gt" => start,
          "$lt" => last
        }}
      end
    end
    private :time_hash, :make_time_cond

    def gaussian(mean, dev)
      theta = 2 * Math::PI * rand
      rho = (-2*Math.log(rand))**0.5
      scale = dev*rho
      mean + scale * Math.cos(theta)
    end

    # make a non-mention tweet
    #
    # @param now [Time] find a suitable tweet in around this time
    def autotweet(now)
      query = {
        "entities.user_mentions" => {
          "$size" => 0
        }
      }.merge(self.make_time_cond(now))
      candidates = @tweets.find(query).to_a
      tw = candidates.sample
      if tw
        text = tw["text"]
        text.gsub!(/(?<=( |　|^|))#/, "■")
        return text if text !~ /@/
      end
      nil
    end

    # Find the suitable reply for message
    #
    # @param message [Message] mention tweet to be replied
    # @return [Array] candidate tweets
    def mention_by_wordnet(message)
      # Classify the message by enumerating higher-order synsets for each word
      tags = []
      Mecab::Ext::Parser.parse(message[:message]).each do |node|
        features = node.feature.split(/,/)
        pos = POS_TABLE[features[0]]
        word = Word.find_by(lemma: node.surface, pos: pos)
        if word
          sense = word.senses.first
          synset = sense.synsets.first
          # Enumerate synsets(max: 2 levels higher)
          tags << synset.synset
          ancestors = synset.ancestors
          if ancestors
            ancestors.each do |ancestor|
              break if ancestor.hops >= 2
              tags << ancestor.synset2
            end
          end
        end
      end

      # Pick up the tweets sharing at least one tag with message
      @db.mentions_by_tags(tags)
    end

    # Find the suitable reply for message, based on current time
    #
    # @param message [Message] message to be replied
    # @return [Array] candidate tweets
    def mention_by_time(message)
      puts "Get mention: #{message.message}"
      now = Time.now
      query = {
        "entities.user_mentions" => {
          "$size" => 1
        }
      }.merge(self.make_time_cond(now))
      candidates = @tweets.find(query).to_a
    end
    private :mention_by_wordnet, :mention_by_time

    # Reply to specified message
    #
    # @param message [Message] message to be replied
    # @return [String] reply tweet
    def reply_to(message)
      candidates = self.mention_by_wordnet(message)
      candidates = self.mention_by_time(message) if candidates.empty?
      selected = candidates.shuffle.find{|tw| tw["text"] !~ /^\s*RT/}
      if selected
        text = selected["text"]
        text = selected["text"]
        text.gsub!(/@[_a-zA-Z0-9]+/, "@#{message.user.idname}")
        return text
      end
      nil
    end
  end
end
