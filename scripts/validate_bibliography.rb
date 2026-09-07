require 'bibtex'
require 'logger'

module BibliographyValidation
  def self.entries(path)
    text = File.read(path, encoding: 'UTF-8')
    raise 'invalid response' if text.lstrip.start_with?('<')
    keys = text.scan(/^\s*@\w+\s*[{(]\s*([^,\s]+)\s*,/).flatten
    raise 'empty or duplicate entries' if keys.empty? || keys.uniq.size != keys.size
    # Parser diagnostics can contain imported data: only emit fixed messages.
    BibTeX.log.level = Logger::UNKNOWN
    bibliography = BibTeX.parse(text)
    entries = bibliography.entries.values
    raise 'BibTeX parsing failed' if bibliography.errors? || entries.size != keys.size
    entries.each do |entry|
      raise 'missing required field' unless %i[title author year url].all? { |k| !entry[k].to_s.strip.empty? }
      raise 'invalid year' unless entry[:year].to_s.match?(/\A\d{4}\z/)
      raise 'invalid URL' unless entry[:url].to_s.match?(/\Ahttps?:\/\//)
    end
    entries
  end

  def self.validate(path, baseline = nil)
    candidate = entries(path)
    if baseline
      previous = entries(baseline)
      raise 'HAL query limit reached' if candidate.size >= 5000
      raise 'unexpected record-count drop' if candidate.size < previous.size * 0.8
    end
    candidate.size
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    count = BibliographyValidation.validate(ARGV.fetch(0), ARGV[1])
    puts "PASS: bibliography validation (#{count} entries)"
  rescue StandardError
    abort 'FAIL: bibliography invalid, incomplete, duplicated, or unexpectedly reduced; contents withheld.'
  end
end
