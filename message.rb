class Message
  require 'twitter'

  # 定数初期化
  EMBED_TIMEOUT = 30  # Embed埋め込み待機時間
  DELETE_RANGE  = 10  # 削除メッセージ検索範囲
  TEMP_SECOND   = 20  # 一時メッセージ表示時間
  RATE_LIMIT    = 100 # 1時間当たりの上限リクエスト数

  NSFW_MESSAGE = "**ツイートにセンシティブな内容が含まれる可能性があるため、表示できません（NSFWチャンネルでのみ表示可）**"
  OVER_RANGE_MESSAGE = "BOTが応答するまでの間にチャンネルに既定数以上のメッセージが送信されました"

  # Twitter APIクライアント初期化
  @@client = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
    config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  end

  # メッセージ生成
  def self.generater(event, message)
    # URLがマッチするか
    match_url = message.content.match(%r{!?https?://twitter\.com/\w+/status/(\d+)})
    return if match_url.nil? || match_url[0].start_with?("!")
    return unless tweet = get_tweet(match_url[1])

    # 画像つきツイートか
    media = get_images(tweet)
    if media.nil?
      expand_quote(event, message, tweet)
      return
    end
    return if media.empty?  # 画像が2枚以上あるか

    # NSFWか
    if check_nsfw(event, tweet)
      event.send_temporary_message(NSFW_MESSAGE, TEMP_SECOND)
      return
    end

    # メッセージID・画像URL挿入
    event << "メッセージ(ID: #{message.id})のツイート画像"
    media.each { |m| event << m.media_url_https }

    # 削除範囲外ではないか
    if check_over(event, message)
      event.send_temporary_message(OVER_RANGE_MESSAGE, TEMP_SECOND)
      event.drain
    end
  end

  # 画像つき引用ツイートの展開
  def self.expand_quote(event, message, tweet)
    return unless tweet.attrs[:is_quote_status]
    return unless quote = get_tweet(tweet.attrs[:quoted_status_id])
    
    # 画像つきツイートか
    media = get_images(quote)
    return if media.nil?
    
    # NSFWか
    if check_nsfw(event, tweet) || check_nsfw(event, quote)
      event.send_temporary_message(NSFW_MESSAGE, TEMP_SECOND)
      return
    end

    # 引用ツイートURL挿入
    event << "メッセージ(ID: #{message.id})の引用ツイート画像"
    event << quote.uri.to_s

    # 画像が2枚以上あるか
    return if media.empty?
    media.each { |m| event << m.media_url_https }

    # 削除範囲外ではないか
    if check_over(event, message)
      event.send_temporary_message(OVER_RANGE_MESSAGE, TEMP_SECOND)
      event.drain
    end
  end

  # ツイート情報を取得
  def self.get_tweet(status)
    begin
      @@client.status(status, { tweet_mode: "extended" })
    rescue
      return
    end
  end

  # ツイート画像を取得
  def self.get_images(tweet)
    media = tweet.media.dup
    return if media.empty? || media[0].type != "photo"
    media.shift # 1枚目の画像URLを破棄
    media
  end

  # NSFWに適合するか
  def self.check_nsfw(event, tweet)
    tweet.attrs[:possibly_sensitive] && !event.channel.nsfw?
  end

  # 削除範囲外か
  def self.check_over(event, message)
    event.channel.history(DELETE_RANGE, nil, message.id).length >= DELETE_RANGE
  end

  # 数字をカンマ区切りの文字列に
  def self.delimit(number)
    number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
  end
end
