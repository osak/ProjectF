require 'mongo'
require 'mecab/ext'
require 'wordnet-ja'

Plugin.create(:fate) do
  @mongo = Mongo::MongoClient.new
  @tweets = @mongo.db("project_f")["tweets"]
  @tagged_tweets = @mongo.db("project_f")["tagged_tweets"]
  UserConfig[:fate_count] ||= 0
  UserConfig[:fate_last_reply_id] ||= nil
  ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: File.join(__dir__, "wnjpn.db"))
  POS_TABLE = {
    '名詞' => 'n',
    '動詞' => 'v',
    '形容詞' => 'a',
    '副詞' => 'r',
  }.freeze


  def time_hash(time)
    time.hour*10000 + time.min*100 + time.sec
  end

  def make_time_cond(now)
    start = time_hash(now-1800)
    last = time_hash(now+1800)
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

  def gaussian(mean, dev)
    theta = 2 * Math::PI * rand
    rho = (-2*Math.log(rand))**0.5
    scale = dev*rho
    mean + scale * Math.cos(theta)
  end

  on_period do |service|
    cnt = UserConfig[:fate_count]
    if cnt <= 0
      now = Time.now
      query = {
        "entities.user_mentions" => {
          "$size" => 0
        }
      }.merge(make_time_cond(now))
      puts query
      candidates = @tweets.find(query).to_a
      tw = candidates.sample
      if tw
        text = tw["text"]
        text.gsub!(/(?<= )#/, "■")
        puts text
        service.update(message: text) if text !~ /@/
      end
      cnt = gaussian(15, 5)
      if cnt < 0
        cnt = -cnt
      end
      puts cnt
    end
    UserConfig[:fate_count] = cnt-1
  end

  def mention_by_wordnet(message)
    Mecab::Ext::Parser.parse(str).each do |node|
      features = node.feature.split(/,/)
      pos = POS_TABLE[features[0]]
      word = Word.find_by(lemma: node.surface, pos: pos)
      if word
        sense = word.senses.first
        synset = sense.synsets.first
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
    candidates = @tagged_tweets.find({tag: {"$in" => tags.uniq}})
    obj_ids = candidates.map{|c| c['obj_id']}
    cand_tweets = @tweets.find({'_id' => {"$in" => obj_ids}, "entities.user_mentions" => {"$size" => 1}})
    cand_tweets.select{|c| c['text'] !~ /\s*RT/}
  end

  def mention_by_time(message)
    puts "Get mention: #{message.message}"
    now = Time.now
    query = {
      "entities.user_mentions" => {
        "$size" => 1
      }
    }.merge(make_time_cond(now))
    candidates = @tweets.find(query).to_a
  end

  on_mention do |service, messages|
    last_reply_id = UserConfig[:fate_last_reply_id]
    messages.each do |message|
      UserConfig[:fate_last_reply_id] = [UserConfig[:fate_last_reply_id] || 0, message.id || 0].max
      next if last_reply_id.nil? || message.id <= last_reply_id
      candidates = mention_by_wordnet(message)
      candidates = mention_by_time(message) if candidates.empty?
      selected = candidates.shuffle.find{|tw| tw["text"] !~ /^\s*RT/}
      if selected
        text = selected["text"]
        text.gsub!(/@[_a-zA-Z0-9]+/, "@#{message.user.idname}")
        puts "Reply to '#{message.message}': #{text}"
        message.post(message: text)
      end
    end
  end

  on_followers_created do
  end
end
