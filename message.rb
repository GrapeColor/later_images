class Message
  require 'twitter'

  # 定数初期化
  EMBED_TIMEOUT = 30  # Embed埋め込み待機時間
  DELETE_RANGE  = 10  # 削除メッセージ検索範囲
  TEMP_SECOND   = 20  # 一時メッセージ表示時間

  # Twitter APIクライアント初期化
  @@client = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
    config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  end

  # メッセージ生成
  ## event      = Discordrb::Events
  ## message_id = Discordrb::Message.id
  ## content    = Discordrb::Message.content
  def self.generater(event, message_id, content)
    # URLがマッチするか
    match_url = content.match(%r{!?https?://twitter.com/\w+/status/(\d+)})
    return if match_url.nil? || match_url[0].start_with?("!")
    tweet = @@client.status(match_url[1], { tweet_mode: "extended" })

    # 画像が2枚以上あるか
    media = tweet.media.dup
    return if media.length <= 1 || media[0].type != "photo"
    media.shift

    # ツイートはNSFWではないか
    if tweet.attrs[:possibly_sensitive] && !event.channel.nsfw?
      event.send_temporary_message("**ツイートにセンシティブな内容が含まれる可能性があるため、画像を表示できません（NSFWチャンネルでのみ表示可）**", TEMP_SECOND)
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

  # 数字をカンマ区切りの文字列に
  ## number = Integer
  def self.delimit(number)
    number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
  end
end
