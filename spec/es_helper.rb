require 'elasticsearch/extensions/test/cluster'
require 'elasticsearch/extensions/test/startup_shutdown'

class ESHelper
  def self.setup
    logger = ::Logger.new(STDERR)
    logger.formatter = lambda { |s, d, p, m| "#{m.ansi(:faint, :cyan)}\n" }
    ActiveRecord::Base.logger = logger unless ENV['QUIET']
    ActiveRecord::LogSubscriber.colorize_logging = false
    ActiveRecord::Migration.verbose = false
    tracer = ::Logger.new(STDERR)
    tracer.formatter = lambda { |s, d, p, m| "#{m.gsub(/^.*$/) { |n| '   ' + n }.ansi(:faint)}\n" }
    es_host = "localhost:#{(ENV['TEST_CLUSTER_PORT'] || 9250)}"
    Elasticsearch::Model.client = Elasticsearch::Client.new host: es_host, tracer: (ENV['QUIET'] ? nil : tracer)
  end

  def self.startup
    unless ENV["ES_SKIP"] || Elasticsearch::Extensions::Test::Cluster.running?
      Elasticsearch::Extensions::Test::Cluster.start(nodes: 1)
    end
  end

  def self.shutdown
    unless ENV["I_AM_HA_CHILD"]
      Elasticsearch::Extensions::Test::Cluster.stop if Elasticsearch::Extensions::Test::Cluster.running?
    end
  end

  def self.client
    Elasticsearch::Model.client
  end
end
