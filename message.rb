class Message
  require 'twitter'

  # 定数初期化
  EMBED_TIMEOUT = 30  # Embed埋め込み待機時間
  DELETE_RANGE  = 10  # 削除メッセージ検索範囲
  TEMP_SECOND   = 15  # 一時メッセージ表示時間
  RATE_LIMIT    = 120 # 1時間当たりの上限リクエスト数

  NSFW_MESSAGE = "**ツイートにセンシティブな内容が含まれる可能性があるため、表示できません（NSFWチャンネルでのみ表示可）**"
  OVER_RANGE_MESSAGE = "BOTが応答するまでの間にチャンネルに既定数以上のメッセージが送信されました"

  # Twitter APIクライアント初期化
  @client = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
    config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  end

  # メッセージ生成
  def self.generater(event, tweet_id, quote = false)
    return unless tweet = get_tweet(tweet_id)
    message = event.message

    # 画像つきツイートか
    media = get_images(tweet)
    if media.nil?
      if !quote && tweet.attrs[:is_quote_status]
        generater(event, tweet.attrs[:quoted_status_id], true)
      end
      return
    end
    return if media.empty? && !quote  # 画像が2枚以上あるか

    # NSFWに適合するか
    if !event.channel.nsfw? && tweet.attrs[:possibly_sensitive]
      event.send_temporary_message(NSFW_MESSAGE, TEMP_SECOND)
      return
    end

    # メッセージID・画像URL挿入
    event << "メッセージ(ID: #{message.id})の#{"引用" if quote}ツイート画像"
    event << tweet.uri.to_s if quote
    media.each { |m| event << m.media_url_https }

    # 削除範囲外ではないか
    if event.channel.history(DELETE_RANGE, nil, message.id).length >= DELETE_RANGE
      event.send_temporary_message(OVER_RANGE_MESSAGE, TEMP_SECOND)
    else
      event.send_message(event.saved_message)
    end
    event.drain
  end

  # メッセージのリプライ先IDを取得
  def self.get_reply_id(message)
    return unless message.from_bot?
    return if message.content !~ /(ID:|[\u{1f194}]|[\u27A1]|REPLY TO:) ([a-z0-9]+)/
    return $2.to_i(36) if $1 != "ID:"
    $2.to_i
  end

  # ツイート情報を取得
  def self.get_tweet(status)
    begin
      @client.status(status, { tweet_mode: "extended" })
    rescue; return; end
  end

  # ツイート画像を取得
  def self.get_images(tweet)
    media = tweet.media
    return if media.empty? || media[0].type != "photo"
    media[1..-1]
  end

  # 数字をカンマ区切りの文字列に
  def self.delimit(number)
    number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
  end
end
