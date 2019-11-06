require 'bundler/setup'
require 'logger'
require 'dotenv'
require 'discordrb'

Dotenv.load
require './message'

waitings = {} # Embed埋め込み待ちメッセージ

# ログ出力に必要な初期化
$stdout.sync = true
app_logger = Logger.new(STDOUT)
requests = { members: 0, bots: 0, webhooks: 0 }
by_users = {}
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
  waitings.delete_if { |id, message| now - message.timestamp > Message::EMBED_TIMEOUT }

  # 1時間ごとのタスク
  if last_log.hour != now.hour
    name = bot.profile.username

    # BOTの使用状況をログ出力
    total = requests.values.inject(:+)
    app_logger.info(name) { "Requested by Members: #{requests[:members]}, Bots: #{requests[:bots]}, Webhooks: #{requests[:webhooks]}, Total: #{total}" }
    app_logger.info(name) { "Used by Servers: #{bot.servers.length}, Users: #{bot.users.length}" }
    app_logger.info(name) { "After #{last_log}" }

    # カウンタ初期化
    requests = { members: 0, bots: 0, webhooks: 0 }
    by_users = {}

    last_log = now
  end
end

# ツイートURLを含むメッセージの送信
bot.message({ contains: Message::URL_PATTERN }) do |event|
  message = event.message

  # Embedが埋め込まれているか
  if message.embeds.empty?
    waitings[message.id] = message
  else
    Message.generater(event, message)
  end

  # リクエスト数カウンタ
  user = event.author

  if user.bot_account?
    if user.webhook?
      requests[:webhooks] += 1
    else
      requests[:bots] += 1
    end
  else
    requests[:members] += 1
  end

  # レートリミッタ
  by_users[user.id] = by_users[user.id].to_i + 1
  if by_users[user.id] > Message::RATE_LIMIT
    bot.ignore_user(user.id)
    app_logger.warn(bot.profile.username) { "Ignore User(#{user.id})" }
  end
end

# メッセージの更新
bot.message_update do |event|
  # 埋め込み待ちメッセージで、Embedが埋め込まれているか
  if !event.message.embeds.empty? && message = waitings.delete(event.message.id)
    Message.generater(event, message)
  end
end

# メッセージの削除
bot.message_delete do |event|
  # 削除メッセージ以降のメッセージを検索
  event.channel.history(Message::DELETE_RANGE, nil, event.id).each do |message|
    # bot自身のメッセージか
    next unless message.from_bot?

    # メッセージIDはあるか
    match_reply = message.content.match(/(ID:|[\u{1f194}]|[\u27A1]|REPLY TO:) ([a-z0-9]+)/)
    next if match_reply.nil?

    # 削除メッセージIDと一致するか
    if event.id == match_reply[2].to_i || event.id == match_reply[2].to_i(36)
      message.delete
    end
  end
end

# 空メンション受け取り
bot.mention({ content: /<@\d+>/ }) do |event|
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

# pingメンション受け取り
bot.mention({ content: /<@\d+> ping/ }) do |event|
  message = event.send_message("計測中...")
  message.edit("応答速度: #{((message.timestamp - event.timestamp) * 1000).round}ms")
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
