require 'mongo'

module ProjectF
  class FateDB
    def initialize
      @mongo = Mongo::MongoClient.new
      @tweets = @mongo.db("project_f")["tweets"]
      @tagged_tweets = @mongo.db("project_f")["tagged_tweets"]
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

    def tweets_around(time, mention: false)
      query = {
        "entities.user_mentions" => {
          "$size" => mention ? 1 : 0
        }
      }.merge(self.make_time_cond(time))
      @tweets.find(query).to_a
    end

    def tweets_by_tags(tags, *additional)
      ids = @tagged_tweets.find({tag: {"$in" => tags.uniq}})
      obj_ids = ids.map{|c| c["obj_id"]}
      cond = {"$in" => obj_ids}
      if additional[0]
        cond.merge!(additionao[0])
      end
      @tweets.find({"_id" => cond})
    end

    def mentions_by_tags(tags)
      self.tweets_by_tags(tags, "entities.user_mentions" => {"$size" => 1})
    end
  end
end

