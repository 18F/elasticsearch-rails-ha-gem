require 'spec_helper'
require 'pp'

describe Elasticsearch::Rails::HA::IndexStager do

  after(:each) do
    ESHelper.client.indices.delete index: "articles_stage" rescue false
  end

  it "generates index names" do
    stager = Elasticsearch::Rails::HA::IndexStager.new('Article')
    expect(stager.stage_index_name).to eq "articles_stage"
    expect(stager.tmp_index_name).to match(/^articles_\d{14}-\w{8}$/)
  end

  it "stages an index" do
    stager = stage_index
    aliases = ESHelper.client.indices.get_aliases(index: stager.stage_index_name)
    expect(aliases.keys.size).to eq 1
    expect(aliases.keys[0]).to eq stager.tmp_index_name
  end

  def stage_index
    stager = Elasticsearch::Rails::HA::IndexStager.new('Article')
    indexer = Elasticsearch::Rails::HA::ParallelIndexer.new(
      klass: stager.klass,
      idx_name: stager.tmp_index_name,
      nprocs: 1,
      batch_size: 5,
      force: true,
      verbose: !ENV['QUIET']
    )   
    indexer.run
    stager.alias_stage_to_tmp_index
    stager
  end
end