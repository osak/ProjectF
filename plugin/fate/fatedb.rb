require 'mongo'
require 'wordnet-ja'

module ProjectF
  class FateDB
    def initialize
      @mongo = Mongo::MongoClient.new
      @tweets = @mongo.db("project_f")["tweets"]
      @tagged_tweets = @mongo.db("project_f")["tagged_tweets"]
      ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: File.join(__dir__, "wnjpn.db"))
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

