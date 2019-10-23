require 'dotenv'
require 'discordrb'
require 'twitter'

Dotenv.load

bot = Discordrb::Bot.new(
  client_id: ENV['DISCORD_CLIENT_ID'],
  token:     ENV['DISCORD_TOKEN']
)

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
  config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
  config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
  config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
end

# プレイ中のゲームを設定
bot.ready { bot.game = "Twitter" }

# "https://twitter.com/"を含むメッセージ
bot.message(attributes = {contains: "https://twitter.com/"}) do |event|
  # URLがマッチするか
  match_url = event.content.match(%r{https://twitter.com/(\w+)/status/(\d+)})
  next if match_url.nil?

  # TweetはNSFWではないか
  tweet = client.status(match_url[2])
  next if tweet.attrs[:possibly_sensitive] && event.channel.nsfw == false
  
  # Embedがあるか(Embedが送られるまで待つ)
  sleep(0.5)
  next if event.channel.load_message(event.message.id).embeds.empty?

  # 画像URLを取得
  tweet.media.each_with_index do |m, index|
    next if index < 1 || m.type != "photo"
    event << "\u27A1 " + event.message.id.to_s(36) if index == 1
    event << m.media_url_https.to_s
  end
end

# メッセージの削除
bot.message_delete do |event|
  # 削除メッセージ以降10件のメッセージを検証
  event.channel.history(10, nil, event.id).each do |message|
    # BOT自身のメッセージか
    next if message.author != bot.profile.id
    
    # リプライ先メッセージIDはあるか
    match_reply = message.content.match(/[\u27A1] ([a-z0-9]+)/) # New pattern
    match_reply = message.content.match(%r{<REPLY TO: ([a-z0-9]+)>}) if match_reply.nil?
    next if match_reply.nil?

    # 削除メッセージIDと一致するか
    if event.id == match_reply[1].to_i(36)
      message.delete
      break
    end
  end
end
 
bot.run
