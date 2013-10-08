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
      #expect(@db).to receive(:tweets_around).with(t)
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
end

