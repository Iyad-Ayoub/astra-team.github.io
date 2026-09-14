source 'https://rubygems.org'
ruby file: '.ruby-version'

# Existing Linux binaries support Ruby < 3.4; compile the same versions instead.
gem 'nokogiri', '1.17.2', force_ruby_platform: true
gem 'google-protobuf', '3.25.8', force_ruby_platform: true
group :jekyll_plugins do
    gem 'wdm', '>= 0.1.0' if Gem.win_platform?
    gem 'jekyll'
    gem 'jekyll-archives'
    gem 'jekyll-diagrams'
    gem 'jekyll-email-protect'
    gem 'jekyll-feed'
    gem 'jekyll-imagemagick'
    gem 'jekyll-minifier'
    gem 'jekyll-paginate-v2'
    gem 'jekyll-scholar'
    gem 'jekyll-sitemap'
    gem 'jekyll-target-blank'
    gem 'jekyll-twitter-plugin'
    gem 'jemoji'
    gem 'unicode_utils'
    gem 'webrick'
    gem 'jekyll-leaflet'
end
group :other_plugins do
    gem 'httparty'
    gem 'feedjira'
end

group :jekyll_plugins do
  gem 'jekyll-responsive-magick', '~> 1.2'
end
