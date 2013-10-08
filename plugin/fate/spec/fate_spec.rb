require File.join(__dir__, "spec_helper.rb")
require File.join(__dir__, "..", "fate.rb")

describe ProjectF::Fate do
  before(:each) do
    @db = mock("fatedb")
    @fate = ProjectF::Fate.new(@db)
  end

  context "autotweet" do
    it "should call tweets_around" do
      t = Time.now
      @db.should_receive(:tweets_around).with(t).and_return([])
      @fate.autotweet(t)
    end

    it "should return tweet body" do
      @db.should_receive(:tweets_around).and_return([text: "　#hashtag1 こんにちは #hashtag2"])
      expect(@fate.autotweet(nil)).to eq("　■hashtag1 こんにちは ■hashtag2")
    end

    it "should not return mention" do
      @db.should_receive(:tweets_around).and_return([text: "　#hashtag1 こんにちは @osa_k #hashtag2"])
      expect(@fate.autotweet(nil)).to be_nil
    end

    it "should return nil on empty candidates" do
      @db.should_receive(:tweets_around).and_return([])
      expect(@fate.autotweet(nil)).to be_nil
    end
  end

  context "reply_to" do
    before(:each) do
      @user = double("user", idname: "osa_k")
      @message = double("message", message: "@_osa_k こんにちは", user: @user, created: Time.now)
      @message.stub(:[]).with(:message).and_return(@message.message)
    end

    it "should call mentions_by_tags" do
      Word.stub(:find_by).and_return(nil)
      @db.should_receive(:mentions_by_tags).and_return([text: "@hoge stub"])
      expect(@fate.reply_to(@message)).to eq("@osa_k stub")
    end

    it "should call mention_by_time" do
      Word.stub(:find_by).and_return(nil)
      @db.stub(:mentions_by_tags).and_return([])
      @db.should_receive(:tweets_around).with(@message.created, mention: true).and_return([text: "@hoge せやな"])
      expect(@fate.reply_to(@message)).to eq("@osa_k せやな")
    end
  end
end

