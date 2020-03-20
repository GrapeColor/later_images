require 'dotenv/load'
require 'discordrb'
require 'twitter'

bot = Discordrb::Bot.new(token: ENV['DISCORD_TOKEN'])

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
  config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
  config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
  config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
end

bot.message do |event|
  next if event.content !~ %r{https://twitter\.com/\w+/status/(\d+)}
  tweet = client.status($1, { tweet_mode: "extended" })
  next if tweet.media.empty?
  next if tweet.media[0].type != "photo"
  tweet.media[1..].map(&:media_url_https).join("\n")
end

bot.run
