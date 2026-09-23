#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require_relative 'validate_site'

base = ARGV.fetch(0, 'origin/main')
branch = ENV.fetch('GITHUB_REF_NAME', `git branch --show-current`.strip)
match = branch.match(%r{\Acms-publish/news/(news-[a-z0-9]+)\z})
raise "invalid CMS publication branch: #{branch}" unless match

content_id = match[1]
output, status = Open3.capture2('git', 'diff', '--name-status', "#{base}...HEAD")
raise "cannot compare CMS publication branch with #{base}" unless status.success?
changes = output.lines.map { |line| line.strip.split("\t", 2) }.reject(&:empty?)
raise 'CMS publication branch has no changes' if changes.empty?

news_changes = changes.select { |_, path| path&.start_with?('_news/') }
raise 'CMS publication must change exactly one public News Markdown file' unless news_changes.size == 1
news_status, news_path = news_changes.first
raise 'CMS publication News Markdown must be added or modified' unless %w[A M].include?(news_status)
raise 'CMS publication News path is invalid' unless news_path.match?(%r{\A_news/[a-z0-9-]+\.md\z})

allowed_media = %r{\Aassets/img/news/#{Regexp.escape(content_id)}/[a-zA-Z0-9_.-]+\.(?:png|jpe?g|gif|webp)\z}
record = SiteValidation.front_matter(news_path)
raise 'CMS publication content ID does not match its branch' unless record['content_id'] == content_id
raise 'CMS publication contains an internal media path' if File.read(news_path).include?('cms/')
if record['image']
  expected = %r{\A/assets/img/news/#{Regexp.escape(content_id)}/[a-zA-Z0-9_.-]+\.(?:png|jpe?g|gif|webp)\z}
  raise 'CMS publication cover path is invalid' unless record['image'].match?(expected)
  raise 'CMS publication cover asset is missing' unless File.file?(record['image'].delete_prefix('/'))
  raise 'CMS publication cover image requires alt text' if record['image_alt'].to_s.strip.empty?
end

media_changes = changes.reject { |_, path| path == news_path }
expected_cover = record['image']&.delete_prefix('/')
media_changes.each do |change_status, path|
  raise "unexpected CMS publication change: #{path}" unless %w[A M].include?(change_status) && path&.match?(allowed_media) && path == expected_cover
end
raise 'CMS publication may change only one owned cover image' if media_changes.size > 1

puts "PASS: controlled CMS publication for #{content_id}"
