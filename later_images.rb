require 'dotenv'
require 'discordrb'
require 'twitter'

Dotenv.load
EMBED_RETRY  = 10  # Embed確認最大回数
DELETE_RANGE = 10  # 削除メッセージ検索範囲

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

# ステータス表示を設定
bot.ready { bot.game = "Twitter | @" + bot.profile.distinct }

# ハートビートイベント
bot.heartbeat do
  # Discordと接続できているか
  unless bot.connected?
    bot.stop
    sleep(60)
    bot.run
  end
end

# ツイートURLを含むメッセージ
bot.message({ contains: "://twitter.com/" }) do |event|
  # URLがマッチするか
  match_url = event.content.match(%r{!?https?://twitter.com/\w+/status/(\d+)})
  next if match_url.nil? || match_url[0].start_with?("!")
  tweet = client.status(match_url[1], { tweet_mode: "extended" })
  
  # 画像が2枚以上あるか
  media = tweet.media.dup
  next if media.length <= 1 || media[0].type != "photo"
  media.shift

  # 変数初期化・入力開始
  channel = event.channel
  message = event.message
  channel.start_typing
  
  # メッセージID・画像URL挿入
  event << "メッセージ(ID: #{message.id})のツイート画像"
  media.each { |m| event << m.media_url_https.to_s }

  # Discord処理待ち
  EMBED_RETRY.times do
    # Embedは埋め込まれているか
    if channel.load_message(message.id).embeds.empty?
      sleep(0.5)
      next
    end

    # ツイートはNSFWではないか
    if tweet.attrs[:possibly_sensitive] && !channel.nsfw?
      event.send_temporary_message("**ツイートにセンシティブな内容が含まれる可能性があるため、画像を表示できません**", 30)
      break
    end

    # メッセージ検索範囲を超えていないか
    if channel.history(DELETE_RANGE, nil, message.id).length < DELETE_RANGE
      event.send_message(event.saved_message)
    else
      event.send_temporary_message("BOTが応答するまでの間にチャンネルに既定以上のメッセージが送信されました", 30)
    end
    break
  end

  event.drain
end

# メッセージの削除
bot.message_delete do |event|
  # 削除メッセージ以降のメッセージを検索
  event.channel.history(DELETE_RANGE, nil, event.id).each do |message|
    # BOT自身のメッセージか
    next if message.author != bot.profile.id
    
    # メッセージIDはあるか
    match_reply = message.content.match(/(ID:|[\u{1f194}]|[\u27A1]|REPLY TO:) ([a-z0-9]+)/)
    next if match_reply.nil?

    # 削除メッセージIDと一致するか
    if event.id == match_reply[2].to_i || event.id == match_reply[2].to_i(36)
      message.delete
      break
    end
  end
end

# メンション受け取り
bot.mention do |event|
  event.channel.start_typing
  event.send_embed do |embed|
    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: bot.profile.username,
      url: ENV['APP_URL'],
      icon_url: bot.profile.avatar_url
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
  event.channel.start_typing
  event << "メッセージありがとうございます。"
  event << "このBOTはTwitterの画像つきツイートのURLがテキストチャンネルに送信されたときに、2枚目以降の画像URLを自動で送信するBOTです。"
  event << "詳細な説明、BOTの招待方法は以下のリンクからご覧ください。"
  event << ENV['APP_README_URL']
end

bot.run
