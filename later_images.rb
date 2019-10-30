require 'dotenv'
require 'discordrb'
require 'twitter'

Dotenv.load
EMBED_TIMEOUT = 30  # Embed埋め込み待機時間
DELETE_RANGE  = 10  # 削除メッセージ検索範囲
TEMP_SECOND   = 10  # 一時メッセージ表示時間

pending_messages = {} # Embed埋め込み待ちメッセージ

bot = Discordrb::Bot.new(
  client_id: ENV['DISCORD_CLIENT_ID'],
  token:     ENV['DISCORD_TOKEN']
)

@client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
  config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
  config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
  config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
end

# ステータス表示を設定
bot.ready { bot.game = "Twitter | @" + bot.profile.distinct }

# ハートビートイベント
bot.heartbeat do
  # タイムアウトしたメッセージを破棄
  now = Time.now
  pending_messages.delete_if { |id, message| now - message.timestamp > EMBED_TIMEOUT }
  
  # Discordと接続できているか
  unless bot.connected?
    bot.stop
    sleep(60)
    bot.run
  end
end

# メッセージ生成
def message_generater(event, message_id, content)
  # URLがマッチするか
  match_url = content.match(%r{!?https?://twitter.com/\w+/status/(\d+)})
  return if match_url.nil? || match_url[0].start_with?("!")
  tweet = @client.status(match_url[1], { tweet_mode: "extended" })
  
  # 画像が2枚以上あるか
  media = tweet.media.dup
  return if media.length <= 1 || media[0].type != "photo"
  media.shift

  event.channel.start_typing
  
  # ツイートはNSFWではないか
  if tweet.attrs[:possibly_sensitive] && !event.channel.nsfw?
    event.send_temporary_message("**ツイートにセンシティブな内容が含まれる可能性があるため、画像を表示できません**", TEMP_SECOND)
    return
  end
  
  # メッセージID・画像URL挿入
  event << "メッセージ(ID: #{message_id})のツイート画像"
  media.each { |m| event << m.media_url_https.to_s }

  # 削除メッセージの検索範囲外ではないか
  if event.channel.history(DELETE_RANGE, nil, message_id).length >= DELETE_RANGE
    event.send_temporary_message("BOTが応答するまでの間にチャンネルに既定以上のメッセージが送信されました", TEMP_SECOND)
    event.drain
  end
end

# ツイートURLを含むメッセージ
bot.message({ contains: "://twitter.com/" }) do |event|
  if event.message.embeds.empty?
    pending_messages[event.message.id] = event.message
    next
  else
    message_generater(event, event.message.id, event.content)
  end
end

# メッセージの更新
bot.message_update do |event|
  if (message = pending_messages[event.message.id]) && !event.message.embeds.empty?
    message_generater(event, event.message.id, message.content)
  end
end

# メッセージの削除
bot.message_delete do |event|
  # 削除メッセージ以降のメッセージを検索
  event.channel.history(DELETE_RANGE, nil, event.id).each do |message|
    # bot自身のメッセージか
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
    embed.description = "画像つきツイートの2枚目以降の画像を表示するbotです"
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
      value: "URLの先頭に「!」を付けるか、URL自体を装飾してください"
    )
    embed.add_field(
      name: "**センシティブコンテンツを含むツイート**",
      value: "NSFWチャンネルでのみ表示できます"
    )
    embed.add_field(
      name: "**botをサーバーに招待したい**",
      value: "botにダイレクトメッセージを送ってください"
    )
  end
end

# ダイレクトメッセージ受け取り
bot.pm do |event|
  event.channel.start_typing
  event << "メッセージありがとうございます。"
  event << "このbotはTwitterの画像つきツイートのURLがテキストチャンネルに送信されたときに、2枚目以降の画像URLを自動で送信するbotです。"
  event << "詳細な説明、botの招待方法は以下のリンクからご覧ください。"
  event << ENV['APP_README_URL']
end

bot.run
