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
  match_url = event.content.match(%r{https://twitter.com/([a-zA-Z0-9_]+)/status/([0-9]+)})
  next if match_url.nil?

  tweet = client.status(match_url[2])
  next if tweet.attrs[:possibly_sensitive] && !event.channel.nsfw

  if tweet.media?
    media = tweet.media
    if media[0].type == "photo"
      photo_urls = media.map { |m| m.media_url_https.to_s }
    end

    if photo_urls.length > 1
      photo_urls.shift
      photo_urls.each { |url| event << url }
    end
  end
end
 
bot.run
