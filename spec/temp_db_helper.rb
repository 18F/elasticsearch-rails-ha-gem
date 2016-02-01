require 'tempfile'

# stub so we can setup schemas below
class Article < ActiveRecord::Base
end

class TempDBHelper
  @@_db_file = nil

  def self.setup
    if @@_db_file
      refresh_db
    end
    setup_schemas
    seed_data
  end

  def self.quiet
    ENV['QUIET']
  end

  def self.db_file
    @@_db_file ||= Tempfile.new('elasticsearch-rails-ha-test.db')
  end

  def self.refresh_db
    quiet or puts "Removing temp db file at #{db_file.path}"
    db_file.close!
    db_file.unlink
    @@_db_file = nil
    open_connection
  end

  def self.open_connection
    quiet or puts "Opening db connection to #{db_file.path}"
    ActiveRecord::Base.establish_connection( :adapter => 'sqlite3', :database => db_file.path )
  end

  def self.setup_schemas
    open_connection
    Article.connection.create_table :articles do |t|
      t.string   :title
      t.string   :body
      t.datetime :created_at, :default => 'NOW()'
    end
  end

  def self.seed_data
    Article.delete_all
    Article.create! title: 'Test',           body: ''
    Article.create! title: 'Testing Coding', body: ''
    Article.create! title: 'Coding',         body: ''
  end
end

TempDBHelper.setup

# extend class with ES definitions -- must do this after setup
#ActiveRecord::Base.raise_in_transactional_callbacks = true
class Article < ActiveRecord::Base
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  settings index: { number_of_shards: 1, number_of_replicas: 0 } do
    mapping do
      indexes :title,      type: 'string', analyzer: 'snowball'
      indexes :body,       type: 'string'
      indexes :created_at, type: 'date'
    end
  end
end

