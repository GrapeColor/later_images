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

# 視聴中メッセージを設定
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

  # レスポンスURLを生成
  respond_id = "https://discordapp.com/channels/#{event.server.id}/#{event.channel.id}/#{event.message.id}"
  
  # ツイートはNSFWではないか
  if tweet.attrs[:possibly_sensitive] && event.channel.nsfw == false
    event << "**このツイートはセンシティブな内容が含まれる可能性があるため、画像を表示できません。**"
    event << "（NSFWチャンネルでのみ表示できます。）"
    event << respond_id
    next
  end

  # 画像URLを取得
  media.each { |m| event << m.media_url_https.to_s }
  
  # Embedがあるか(10回リトライ)
  (1..10).each do |n|
    sleep(0.1 * n)
    unless event.channel.load_message(event.message.id).embeds.empty?
      event.send_message(event.saved_message + respond_id)
      break
    end
  end
  event.drain
end

# メッセージの削除
bot.message_delete do |event|
  # 削除メッセージ以降10件のメッセージを検証
  event.channel.history(10, nil, event.id).each do |message|
    # BOT自身のメッセージか
    next if message.author != bot.profile.id
    
    # レスポンスURL・IDはあるか
    match_reply = message.content.match(%r{https://discordapp.com/channels/(\d+)/(\d+)/(\d+)})
    match_reply = message.content.match(/([\u{1f194}]|[\u27A1]|REPLY TO:) ([a-z0-9]+)/) if match_reply.nil?
    next if match_reply.nil?

    # 削除メッセージIDと一致するか
    if event.id == match_reply[3].to_i || event.id == match_reply[2].to_i(36)
      message.delete
      break
    end
  end
end

# メンション受け取り
bot.mention do |event|
  event.send_embed do |embed|
    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: "Later Images",
      url: 'https://github.com/GrapeColor/later_images',
      icon_url: 'https://cdn.discordapp.com/app-icons/629507137995014164/fa55fe16f7a9a51389d6efff6db60417.png'
    )
    embed.color = 0x1da1f2
    embed.description = "画像つきツイートの2枚目以降の画像を表示するBOTです"
    embed.add_field(
      name: "**使い方**", 
      value: "画像が2枚以上含まれたツイートのURLをメッセージで送信してください"
    )
    embed.add_field(
      name: "**画像を削除したいとき**",
      value: "ツイートのURLを含むメッセージを削除してください"
    )
    embed.add_field(
      name: "**画像を表示して欲しくないとき**",
      value: "URLの先頭に`!`を付けるか、URL自体を装飾してください"
    )
    embed.add_field(
      name: "**センシティブコンテンツを含むツイート**",
      value: "NSFWチャンネルでのみ表示できます"
    )
    embed.add_field(
      name: "**BOTをサーバーに招待したい**",
      value: "BOTにダイレクトメッセージを送ってください"
    )
  end
end

# ダイレクトメッセージ受け取り
bot.pm do |event|
  event << "メッセージありがとうございます。"
  event << "このBOTは画像つきツイートがテキストチャンネルに送信されたときに、2枚目以降の画像を自動で送信するBOTです。"
  event << "詳細な説明、BOTの招待方法は以下のリンクからご覧ください。"
  event << "https://github.com/GrapeColor/later_images/blob/master/readme.md"
end

bot.run
