require 'dotenv/load'
require './later_images'

later_images = LaterImages.new(ENV['LATER_IMAGES_TOKEN'])
later_images.run
