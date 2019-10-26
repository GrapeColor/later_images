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
bot.ready { bot.watching = "Twitter" }

# "https://twitter.com/"を含むメッセージ
bot.message(attributes = { contains: "://twitter.com/" }) do |event|
  # URLがマッチするか
  match_url = event.content.match(%r{!?https?://twitter.com/(\w+)/status/(\d+)})
  next if match_url.nil? || match_url[0].start_with?("!")
  tweet = client.status(match_url[2], { tweet_mode: "extended" })
  
  # 画像が2枚以上あるか
  media = tweet.media.dup
  next if media.length <= 1 || media[0].type != "photo"
  media.shift

  # レスポンスIDを挿入
  event << "\u{1f194} " + event.message.id.to_s(36) + " (@" + match_url[1] + ")"
  
  # ツイートはNSFWではないか
  if tweet.attrs[:possibly_sensitive] && event.channel.nsfw == false
    event << "**センシティブな内容が含まれる可能性があるため、表示できません。**"
    next
  end

  # 画像URLを取得
  media.each { |m| event << m.media_url_https.to_s }
  
  # Embedがあるか(10回リトライ)
  10.times do |count|
    unless event.channel.load_message(event.message.id).embeds.empty?
      event.send_message(event.saved_message)
      break
    end
    sleep(0.1 * (count + 1))
  end
  event.drain
end

# メッセージの削除
bot.message_delete do |event|
  # 削除メッセージ以降10件のメッセージを検証
  event.channel.history(10, nil, event.id).each do |message|
    # BOT自身のメッセージか
    next if message.author != bot.profile.id
    
    # レスポンスIDはあるか
    match_reply = message.content.match(/([\u{1f194}]|[\u27A1]|REPLY TO:) ([a-z0-9]+)/)
    next if match_reply.nil?

    # 削除メッセージIDと一致するか
    if event.id == match_reply[2].to_i(36)
      message.delete
      break
    end
  end
end

# ダイレクトメッセージ受け取り
bot.pm do |event|
  event << "メッセージありがとうございます。"
  event << "このBOTは画像つきツイートがテキストチャンネルに送信されたときに、2枚目以降の画像を自動で送信するBOTです。"
  event << "詳細な説明は以下のリンクからご覧ください。"
  event << "https://github.com/GrapeColor/later_images/blob/master/readme.md"
end

bot.run
