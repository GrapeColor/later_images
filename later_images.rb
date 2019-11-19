require 'dotenv'
require 'discordrb'

Dotenv.load
DELETE_RANGE = 10  # 削除メッセージ検索範囲

# メッセージのリプライ先IDを取得
def get_reply_id(message)
  return unless message.from_bot?
  return if message.content !~ /(ID:|[\u{1f194}]|[\u27A1]|REPLY TO:) ([a-z0-9]+)/
  return $2.to_i(36) if $1 != "ID:"
  $2.to_i
end

today = Time.now
bot = Discordrb::Bot.new(token: ENV['DISCORD_TOKEN'])

# ステータス表示を設定
bot.ready do
  bot.dnd
  bot.game = "@" + bot.profile.distinct
end

# 定期実行イベント
bot.heartbeat do
  today = Time.now
  if today.year == 2020
    bot.servers.values.each {|server| server.leave }
  end
end

# メッセージの削除
bot.message_delete do |event|
  # 削除メッセージ以降のメッセージを検索
  event.channel.history(DELETE_RANGE, nil, event.id).each do |message|
    message.delete if event.id == get_reply_id(message)
  end
end

# 空メンション受け取り
bot.mention do |event|
  next if event.content !~ /^<@!?\d+> ?(.*)/

  case $1
  when /\d+/  # メッセージ削除済み確認
    next unless message = event.channel.load_message($&.to_i)
    next unless reply_id = get_reply_id(message)
    origin = event.channel.load_message(reply_id)
    message.delete unless origin && event.message.author.id != origin.author.id

  when "ping" # ping測定
    message = event.send_message("計測中...")
    message.edit("応答速度: #{((message.timestamp - event.timestamp) * 1000).round}ms")

  else  # BOTの使用方法を返す
    event.send_embed do |embed|
      embed.color = 0x1da1f2
      embed.color = 0x316745 if today.month == 1  && today.day == 1
      embed.color = 0x762e05 if today.month == 2  && today.day == 14
      embed.color = 0xe5a323 if today.month == 10 && today.day == 31
      embed.color = 0xe60033 if today.month == 12 && today.day == 25

      embed.title = "#{event.server.member(bot.profile.id).display_name} の使い方"
      embed.description = <<DESC
画像つきツイートの全画像を表示するBOTです

**■ お知らせ**
このBOTはDiscordの仕様変更に伴い、画像表示機能の提供を終了させて頂きました。
2019年中は削除機能のみ引き続き提供させて頂きます。
ご利用ありがとうございました。

**■ 画像を削除する方法**
ツイートのURLを含むメッセージを削除してください

**■ 残った画像を削除する方法**
`@#{bot.profile.distinct}` に続いて残った画像のメッセージIDを付けて送信してください
例: `@#{bot.profile.distinct} 646261660679405570`
DESC
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Created by GrapeColor.")
    end
  end
end

bot.run
