require 'bundler/setup'
require 'logger'
require 'dotenv'
require 'discordrb'

Dotenv.load
require './message'

waiting_messages = {} # Embed埋め込み待ちメッセージ

# ログ出力に必要な初期化
$stdout.sync = true
app_logger = Logger.new(STDOUT)
request_counter = { members: 0, bots: 0, webhooks: 0 }
last_log = Time.now

bot = Discordrb::Bot.new(
  name: "Later Images",
  client_id: ENV['DISCORD_CLIENT_ID'],
  token: ENV['DISCORD_TOKEN']
)

# ステータス表示を設定
bot.ready { bot.game = "Twitter | @" + bot.profile.distinct }

# ハートビートイベント
bot.heartbeat do
  now = Time.now

  # タイムアウトしたメッセージを破棄
  waiting_messages.delete_if { |id, message| now - message.timestamp > Message::EMBED_TIMEOUT }

  # 1時間あたりのリクエスト数などのログ
  if last_log.hour != now.hour
    name = bot.profile.username
    app_logger.info(name) { "Requested by Members: #{request_counter[:members]}, Bots: #{request_counter[:bots]}, Webhooks: #{request_counter[:webhooks]}" }
    app_logger.info(name) { "Used by Servers: #{bot.servers.length}, Users: #{bot.users.length}" }
    app_logger.info(name) { "Between #{last_log} and #{now}" }
    
    request_counter = { members: 0, bots: 0, webhooks: 0 }
    last_log = now
  end
end

# ツイートURLを含むメッセージの送信
bot.message({ contains: "://twitter.com/" }) do |event|
  message = event.message

  # Embedが埋め込まれているか
  if message.embeds.empty?
    waiting_messages[message.id] = message
  else
    Message.generater(event, message)
  end
  
  # リクエスト数カウンタ
  user = event.author
  if user.bot_account?
    if user.webhook?
      request_counter[:webhooks] += 1
    else
      request_counter[:bots] += 1
    end
  else
    request_counter[:members] += 1
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
      value: "画像つきツイートのURLをメッセージで送信してください"
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
      name: "**BOTを別のサーバーに招待したい**",
      value: "BOT宛にダイレクトメッセージを送ってください"
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
