require 'bundler/setup'
require 'dotenv'
require 'discordrb'

Dotenv.load
require './message'

waiting_messages = {} # Embed埋め込み待ちメッセージ

bot = Discordrb::Bot.new(
  name: "Later Images",
  client_id: ENV['DISCORD_CLIENT_ID'],
  token: ENV['DISCORD_TOKEN']
)

# ステータス表示を設定
bot.ready { bot.game = "Twitter | @" + bot.profile.distinct }

# ハートビートイベント
bot.heartbeat do
  # タイムアウトしたメッセージを破棄
  now = Time.now
  waiting_messages.delete_if { |id, message| now - message.timestamp > Message::EMBED_TIMEOUT }
end

# ツイートURLを含むメッセージの送信
bot.message({ contains: "://twitter.com/" }) do |event|
  # Embedが埋め込まれているか
  if event.message.embeds.empty?
    waiting_messages[event.message.id] = event.message
    next
  else
    Message.generater(event, event.message)
  end
end

# メッセージの更新
bot.message_update do |event|
  # 埋め込み待ちメッセージで、Embedが埋め込まれているか
  if (message = waiting_messages[event.message.id]) && !event.message.embeds.empty?
    Message.generater(event, message)
  end
end

# メッセージの削除
bot.message_delete do |event|
  # 削除メッセージ以降のメッセージを検索
  event.channel.history(Message::DELETE_RANGE, nil, event.id).each do |message|
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
  event.send_embed do |embed|
    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: bot.profile.username,
      url: ENV['APP_URL'],
      icon_url: bot.profile.avatar_url
    )
    embed.color = 0x1da1f2
    embed.description = "画像つきツイートの全画像を表示するBOTです"
    embed.add_field(
      name: "**使い方**", 
      value: "画像が含まれたツイートのURLをメッセージで送信してください"
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
      name: "**BOTをサーバーに招待したい**",
      value: "BOTにダイレクトメッセージを送ってください"
    )
  end
end

# ダイレクトメッセージ受け取り
bot.pm do |event|
  total_servers = Message.delimit(bot.servers.length)
  total_users   = Message.delimit(bot.users.length)
  event << "メッセージありがとうございます。"
  event << "このBOTはTwitterの画像つきツイートのURLがテキストチャンネルに送信されたときに、ツイートに含まれる全画像のURLを自動で送信するBOTです。"
  event << "現在 **#{total_servers}** サーバー、**#{total_users}** ユーザーの方にご利用いただいています。"
  event << "詳細な説明、BOTの招待方法は以下のリンクからご覧ください。"
  event << ENV['APP_README_URL']
end

bot.run
