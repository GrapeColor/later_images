require 'dotenv'
require 'discordrb'
require 'twitter'

Dotenv.load

bot = Discordrb::Bot.new(
  client_id: ENV['DISCORD_CLIENT_ID'],
  token:     ENV['DISCORD_TOKEN']
)

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
  config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
  config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
  config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
end

bot.ready { bot.game = "Twitter" }

bot.message(attributes = {contains: "https://twitter.com/"}) do |event|
  tweet_id = event.content.match(%r{https://twitter.com/(\w+)/status/(\d+)})[2]
  next if tweet_id.nil?

  tweet = client.status(tweet_id)
  next if tweet.attrs[:possibly_sensitive] && event.channel.nsfw == false

  tweet.media.each_with_index do |m, index|
    next if index < 1 || m.type != "photo"
    event << m.media_url_https.to_s
  end
end
 
bot.run
