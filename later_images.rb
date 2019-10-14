require 'dotenv'
require 'discordrb'
require 'twitter'

Dotenv.load

bot = Discordrb::Bot.new(
  client_id: ENV['DISCORD_CLIENT_ID'],
  token: ENV['DISCORD_TOKEN']
)

@client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
  config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
  config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
  config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
end

bot.ready do
  bot.game = 'Twitter'
end

bot.message do |event|
  content = event.message.content
  m = content.match(/https:\/\/twitter.com\/([a-zA-Z0-9_]+)\/status\/([0-9]+)/)
  next if m.nil?

  twitter_url = m[0]
  tweet = @client.status(m[2])

  if tweet.media?
    media = tweet.media
    photo_urls = []
    if media[0].type == "photo"
      media.each { |m| photo_urls.push(m.media_url_https.to_s) }
    end

    if photo_urls.length > 1
      photo_urls.shift
      photo_urls.each do |url|
        event.respond url
      end
    end
  end
end
 
bot.run