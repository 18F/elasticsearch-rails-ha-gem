RUBY_1_8 = defined?(RUBY_VERSION) && RUBY_VERSION < '1.9'

exit(0) if RUBY_1_8

require 'simplecov' and SimpleCov.start { add_filter "/test|test_/" } if ENV["COVERAGE"]

# Register `at_exit` handler for integration tests shutdown.
# MUST be called before requiring `test/unit`.
at_exit { Elasticsearch::Test::HA.__run_at_exit_hooks }

puts '-'*80

if defined?(RUBY_VERSION) && RUBY_VERSION > '2.2'
  require 'test-unit'
  require 'mocha/test_unit'
else
  require 'minitest/autorun'
  require 'mocha/mini_test'
end

require 'shoulda-context'

require 'turn' unless ENV["TM_FILEPATH"] || ENV["NOTURN"] || defined?(RUBY_VERSION) && RUBY_VERSION > '2.2'

require 'ansi'
require 'oj'

require 'rails/version'
require 'active_record'
require 'active_model'

require 'elasticsearch/model'
require 'elasticsearch/rails'

require 'elasticsearch/extensions/test/cluster'
require 'elasticsearch/extensions/test/startup_shutdown'

require 'tempfile'
require 'elasticsearch/rails/ha'

module Elasticsearch
  module Test
    class HA < ::Test::Unit::TestCase
      extend Elasticsearch::Extensions::Test::StartupShutdown

      TEST_DB_FILE = Tempfile.new('elasticsearch-rails-ha-test.db')

      startup do
        Elasticsearch::Extensions::Test::Cluster.start(nodes: 1) unless Elasticsearch::Extensions::Test::Cluster.running? 
      end 
    
      shutdown do
        unless ENV["I_AM_HA_CHILD"]
          Elasticsearch::Extensions::Test::Cluster.stop if started?
          TEST_DB_FILE.unlink
        end
      end   
    
      context "IntegrationTest" do; should "noop on Ruby 1.8" do; end; end if RUBY_1_8
    
      def setup
        ActiveRecord::Base.establish_connection( :adapter => 'sqlite3', :database => TEST_DB_FILE )
        logger = ::Logger.new(STDERR)
        logger.formatter = lambda { |s, d, p, m| "#{m.ansi(:faint, :cyan)}\n" }
        ActiveRecord::Base.logger = logger unless ENV['QUIET']
    
        ActiveRecord::LogSubscriber.colorize_logging = false
        ActiveRecord::Migration.verbose = false
    
        tracer = ::Logger.new(STDERR)
        tracer.formatter = lambda { |s, d, p, m| "#{m.gsub(/^.*$/) { |n| '   ' + n }.ansi(:faint)}\n" }
    
        Elasticsearch::Model.client = Elasticsearch::Client.new host: "localhost:#{(ENV['TEST_CLUSTER_PORT'] || 9250)}",                                                                tracer: (ENV['QUIET'] ? nil : tracer)
      end
    end
  end
end
