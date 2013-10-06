#-*- encoding: utf-8 -*-
require 'mongo'
require 'mecab/ext'
require 'wordnet-ja'
require File.join(__dir__, 'fate.rb')

Plugin.create(:mikutter_fate) do
  @fate = ProjectF::Fate.new
  def gaussian(mean, dev)
    theta = 2 * Math::PI * rand
    rho = (-2*Math.log(rand))**0.5
    scale = dev*rho
    mean + scale * Math.cos(theta)
  end

  on_period do |service|
    cnt = UserConfig[:fate_count]
    if cnt <= 0
      tw = @fate.autotweet(Time.now)
      if tw
        service.update(message: tw)
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
      next if last_reply_id.nil? || message.id <= last_reply_id
      reply = @fate.reply_to(message)
      if reply
        message.post(message: reply)
      end
    end
  end

  on_followers_created do
  end
end
