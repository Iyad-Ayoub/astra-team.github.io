require 'minitest/autorun'
require 'bundler'
require 'digest'
require 'json'

class Phase10DRuntimeTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def test_runtime_and_lock_agree
    assert_equal File.read(File.join(ROOT, '.ruby-version')).strip, RUBY_VERSION
    assert_equal '3.4.10', RUBY_VERSION
    assert_equal '3.6.9', Gem::VERSION
    assert_equal '2.6.9', Bundler::VERSION
    lock = Bundler::LockfileParser.new(File.read(File.join(ROOT, 'Gemfile.lock')))
    assert_equal '2.6.9', lock.bundler_version.to_s
    versions = lock.specs.map { |s| [s.name, s.version.to_s] }.sort
    assert_equal [['mini_portile2', '2.8.9']], versions.select { |name, _| name == 'mini_portile2' }
    original = versions.reject { |name, _| name == 'mini_portile2' }
    assert_equal 90, original.size
    assert_equal '89c8ba95145af9e8d774e6618e5b66c3b95ae3debcbac69243cf1d3bc931b175', Digest::SHA256.hexdigest(JSON.generate(original))
  end

  def test_native_extensions_load_for_the_current_abi
    %w[nokogiri google/protobuf sass-embedded ffi eventmachine http_parser bigdecimal date json racc/cparse stringio].each { |library| require library }
    %w[nokogiri google-protobuf].each do |name|
      assert_equal 'ruby', Gem.loaded_specs.fetch(name).platform.to_s
    end
    assert_equal '1.17.2', Nokogiri::VERSION
    assert_equal '3.25.8', Gem.loaded_specs.fetch('google-protobuf').version.to_s
  end
end
