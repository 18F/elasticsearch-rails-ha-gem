require 'spec_helper'

describe Elasticsearch::Rails::HA::ParallelIndexer do
  it "creates index using parallel indexers" do
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

    expect(response.results.size).to eq 2
  end
end
