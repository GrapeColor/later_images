require 'bundler/setup'
require 'dotenv'
require 'discordrb'

Dotenv.load
require './message.rb'

pending_messages = {} # Embed埋め込み待ちメッセージ

bot = Discordrb::Bot.new(client_id: ENV['DISCORD_CLIENT_ID'], token: ENV['DISCORD_TOKEN'])

# ステータス表示を設定
bot.ready { bot.game = "Twitter | @" + bot.profile.distinct }

# ハートビートイベント
bot.heartbeat do
  # タイムアウトしたメッセージを破棄
  now = Time.now
  pending_messages.delete_if { |id, message| now - message.timestamp > Message::EMBED_TIMEOUT }
end

# ツイートURLを含むメッセージの送信
bot.message({ contains: "://twitter.com/" }) do |event|
  if event.message.embeds.empty?
    pending_messages[event.message.id] = event.message
    next
  else
    Message.generater(event, event.message.id, event.content)
  end
end

# メッセージの更新
bot.message_update do |event|
  if (message = pending_messages[event.message.id]) && !event.message.embeds.empty?
    Message.generater(event, event.message.id, message.content)
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
  event << "メッセージありがとうございます。"
  event << "このbotはTwitterの画像つきツイートのURLがテキストチャンネルに送信されたときに、2枚目以降の画像URLを自動で送信するbotです。"
  event << "詳細な説明、botの招待方法は以下のリンクからご覧ください。"
  event << ENV['APP_README_URL']
end

bot.run
