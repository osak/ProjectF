require 'mongo'

Plugin.create(:fate) do
  @mongo = Mongo::MongoClient.new
  @tweets = @mongo.db("project_f")["tweets"]
  UserConfig[:fate_count] ||= 0

  def time_hash(time)
    time.hour*10000 + time.min*100 + time.sec
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
        created_at_time: {
          "$gt" => time_hash(now-1800),
          "$lt" => time_hash(now+1800)
        },
        "entities.user_mentions" => {
          "$size" => 0
        }
      }
      puts query
      candidates = @tweets.find(query).to_a
      tw = candidates.sample
      tw.gsub!(/(?= )\#/, "■")
      puts tw
      service.update(message: tw["text"])
      cnt = gaussian(15, 5)
      if cnt < 0
        cnt = -cnt
      end
      puts cnt
    end
    UserConfig[:fate_count] = cnt-1
  end

  on_mention do |service, messages|
    messages.each do |message|
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
end
