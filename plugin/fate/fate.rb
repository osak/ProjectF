require 'mongo'

Plugin.create(:fate) do
  @mongo = Mongo::MongoClient.new
  @tweets = @mongo.db("project_f")["tweets"]
  UserConfig[:fate_count] ||= 0
  UserConfig[:fate_last_reply_id] ||= nil

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
        text.gsub!(/(?= )#/, "■")
        puts text
        service.update(message: text)
      end
      cnt = gaussian(15, 5)
      if cnt < 0
        cnt = -cnt
      end
      puts cnt
    end
    UserConfig[:fate_count] = cnt-1
  end

  on_mention do |service, messages|
    last_reply_id = UserConfig[:fate_last_reply_id]
    messages.each do |message|
      UserConfig[:fate_last_reply_id] = [UserConfig[:fate_last_reply_id] || 0, message.id || 0].max
      next if last_reply_id.nil? || message.id < last_reply_id
      puts "Get mention: #{message.message}"
      now = Time.now
      query = {
        created_at_time: {
          "$gt" => time_hash(now-1800),
          "$lt" => time_hash(now+1800)
        },
        "entities.user_mentions" => {
          "$size" => 1
        }
      }
      candidates = @tweets.find(query).to_a
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
