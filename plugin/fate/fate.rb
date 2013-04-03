require 'mongo'

Plugin.create(:fate) do
  @mongo = Mongo::MongoClient.new
  @tweets = @mongo.db("project_f")["tweets"]
  @cnt = 0

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
    if @cnt <= 0
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
      puts tw
      service.update(message: tw["text"])
      @cnt = gaussian(15, 5)
      if @cnt < 0
        @cnt = -@cnt
      end
      puts @cnt
    end
    @cnt -= 1
  end
end