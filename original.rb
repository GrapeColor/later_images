require 'dotenv'
require 'discordrb'
require 'twitter'

Dotenv.load
bot = Discordrb::Bot.new(client_id: ENV['DISCORD_CLIENT_ID'], token: ENV['DISCORD_TOKEN'])

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
  config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
  config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
  config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
end

bot.message do |event|
  match_url = event.content.match(%r{https://twitter.com/\w+/status/(\d+)})
  next if match_url.nil?
  media = client.status(match_url[1], { tweet_mode: "extended" }).media.dup
  next if media.length <= 1 || media[0].type != "photo"
  media.shift
  media.each { |m| event << m.media_url_https.to_s }
end

bot.run
