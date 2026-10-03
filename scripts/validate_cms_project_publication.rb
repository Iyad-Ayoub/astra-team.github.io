#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require_relative 'validate_site'

base = ARGV.fetch(0, 'origin/main')
branch = ENV.fetch('GITHUB_REF_NAME', `git branch --show-current`.strip)
match = branch.match(%r{\Acms-publish/projects/(project-[a-z0-9]+)\z})
raise "invalid CMS project publication branch: #{branch}" unless match

content_id = match[1]
output, status = Open3.capture2('git', 'diff', '--name-status', "#{base}...HEAD")
raise "cannot compare CMS publication branch with #{base}" unless status.success?
changes = output.lines.map { |line| line.strip.split("\t", 2) }.reject(&:empty?)
raise 'CMS project publication branch has no changes' if changes.empty?

project_changes = changes.select { |_, path| path == "_projects/#{content_id}.md" }
raise 'CMS project publication must change exactly one Project Markdown file' unless project_changes.size == 1
project_status, project_path = project_changes.first
raise 'CMS project Markdown must be added or modified' unless %w[A M].include?(project_status)
raise 'CMS project path is invalid' unless project_path.match?(%r{\A_projects/project-[a-z0-9]+\.md\z})

content = File.read(project_path)
record = SiteValidation.front_matter(project_path)
allowed = %w[content_id acronym order title status scope type programme start_date end_date kickoff_date coordinator astra_role partners summary external_url cordis_url cover_media_id cover_image cover_image_alt]
raise 'CMS project contains unsupported front matter' unless (record.keys - allowed).empty?
raise 'CMS project content ID does not match its branch' unless record['content_id'] == content_id
raise 'CMS project content ID is invalid' unless content_id.match?(/\Aproject-[a-z0-9]+\z/)
%w[acronym title summary astra_role].each { |field| raise "CMS project #{field} is required" if record[field].to_s.strip.empty? }
raise 'CMS project status is invalid' unless %w[ongoing completed].include?(record['status'])
raise 'CMS project scope is invalid' unless %w[national european international].include?(record['scope'])
raise 'CMS project type is invalid' unless %w[research-project research-infrastructure joint-lab].include?(record['type'])
raise 'CMS project partners must be an array' unless record['partners'].is_a?(Array)
raise 'CMS project body contract is invalid' unless content.match?(/\A---\n.*?\n---\n\n\{% include project_details\.html %\}\n\z/m)
unsafe_content = content.sub(/\n\{% include project_details\.html %\}\n\z/, "\n")
raise 'CMS project contains unsafe content' if unsafe_content.match?(%r{\{\{|\{%|<\s*script\b|\son[a-z]+\s*=}i)
%w[start_date end_date kickoff_date].each do |field|
  value = record[field]
  next if value.nil? || value.to_s.empty?
  raise "CMS project #{field} is invalid" unless value.to_s.match?(/\A\d{4}-\d{2}(?:-\d{2})?\z/)
end
%w[external_url cordis_url].each do |field|
  value = record[field]
  next if value.nil? || value.to_s.empty?
  raise "CMS project #{field} is invalid" unless value.to_s.match?(%r{\Ahttps?://}i)
end
if record['cover_media_id'] && !record['cover_media_id'].to_s.match?(/\Amedia-[a-z0-9]+\z/)
  raise 'CMS project cover media ID is invalid'
end
if record['cover_media_id']
  expected_cover = %r{\A/assets/img/projects/#{Regexp.escape(content_id)}/[a-zA-Z0-9_.-]+\.(?:png|jpe?g|webp)\z}
  raise 'CMS project cover image path is invalid' unless record['cover_image'].to_s.match?(expected_cover)
  raise 'CMS project cover asset is missing' unless File.file?(record['cover_image'].delete_prefix('/'))
  raise 'CMS project cover image requires alt text' if record['cover_image_alt'].to_s.strip.empty?
else
  raise 'CMS project cover image is not allowed without cover media' if record['cover_image'] || record['cover_image_alt']
end

allowed_media = %r{\Aassets/img/projects/#{Regexp.escape(content_id)}/[a-zA-Z0-9_.-]+\.(?:png|jpe?g|webp)\z}
media_changes = changes.reject { |_, path| path == project_path }
media_changes.each do |change_status, path|
  raise "unexpected CMS project publication change: #{path}" unless %w[A M].include?(change_status) && path&.match?(allowed_media) && path == record['cover_image']&.delete_prefix('/')
end
raise 'CMS project publication may change only one owned cover image' if media_changes.size > 1

puts "PASS: controlled CMS project publication for #{content_id}"
