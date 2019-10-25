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
bot.message(attributes = { contains: "https://twitter.com/" }) do |event|
  # URLがマッチするか
  match_url = event.content.match(%r{https://twitter.com/(\w+)/status/(\d+)})
  next if match_url.nil?
  tweet = client.status(match_url[2], { tweet_mode: "extended" })
  
  # 画像が2枚以上あるか
  media = tweet.media.dup
  next if media.length <= 1 || media[0].type != "photo"
  media.shift

  # レスポンスIDを挿入
  event << "\u27A1 " + event.message.id.to_s(36)
  
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
    match_reply = message.content.match(/[\u27A1] ([a-z0-9]+)/) # 新パターン
    match_reply = message.content.match(%r{<REPLY TO: ([a-z0-9]+)>}) if match_reply.nil?
    next if match_reply.nil?

    # 削除メッセージIDと一致するか
    if event.id == match_reply[1].to_i(36)
      message.delete
      break
    end
  end
end

# ダイレクトメッセージ受け取り
bot.pm do |event|
  event << "メッセージありがとうございます。"
  event << "このBOTは画像つきツイートが送信されたときに、2枚目以降の画像をチャンネルに送信するBOTです。"
  event << "以下のリンクからサーバーに招待できます。"
  event.send_message(event.drain_into(bot.invite_url() + " （権限なし招待リンク）"))
  event.send_message(bot.invite_url(permission_bits: 84992) + " （権限つき招待リンク）")
end

bot.run
