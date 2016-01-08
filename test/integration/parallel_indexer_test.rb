require 'test_helper'
require 'active_record'

class Elasticsearch::Test::ParallelIndexerIntegration < Elasticsearch::Test::HA
  context "ActiveRecord integration" do

    setup do
      TempSqlite.refresh_db
      ActiveRecord::Base.raise_in_transactional_callbacks = true
      ActiveRecord::Schema.define(:version => 1) do
        create_table :articles do |t|
          t.string   :title
          t.string   :body
          t.datetime :created_at, :default => 'NOW()'
        end
      end

      class ::Article < ActiveRecord::Base
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

      Article.delete_all

      ::Article.create! title: 'Test',           body: ''
      ::Article.create! title: 'Testing Coding', body: ''
      ::Article.create! title: 'Coding',         body: ''

      Article.__elasticsearch__.create_index! force: true
      Article.__elasticsearch__.refresh_index!
    end

    should "create index using parallel indexers" do
      indexer = Elasticsearch::Rails::HA::ParallelIndexer.new(
        klass: Article, 
        idx_name: Article.index_name, 
        nprocs: 2, 
        batch_size: 2,
        verbose: !ENV["QUIET"]
      )
      Article.__elasticsearch__.create_index! force: true
      indexer.run
      Article.__elasticsearch__.refresh_index!
      response = Article.search('title:test')

      assert response.any?, "Response should not be empty: #{response.to_a.inspect}"

      assert_equal 2, response.results.size
    end

  end
end
