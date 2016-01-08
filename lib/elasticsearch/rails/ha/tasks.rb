# Rake tasks to make parallel indexing and high availability easier.

require 'elasticsearch/rails/ha'

namespace :elasticsearch do
  namespace :ha do

    desc "import records in parallel"
    task :import do
      nprocs     = ENV['NPROCS'] || 1
      batch_size = ENV['BATCH']  || 100
      max        = ENV['MAX']    || nil
      klass      = ENV['CLASS'] or fail "CLASS required"

      indexer = Elasticsearch::Rails::HA::ParallelIndexer.new(
        klass: klass.constantize,
        idx_name: (ENV['INDEX'] || klass.constantize.index_name),
        nprocs: nprocs.to_i,
        batch_size: batch_size.to_i,
        max: max,
        scope: ENV.fetch('SCOPE', nil),
        force: ENV['FORCE'],
        verbose: !ENV['QUIET']
      )

      indexer.run
    end

    desc "stage an index"
    task :stage do
      nprocs     = ENV['NPROCS'] || 1
      batch_size = ENV['BATCH']  || 100
      max        = ENV['MAX']    || nil
      klass      = ENV['CLASS'] or fail "CLASS required"

      stager = Elasticsearch::Rails::HA::IndexStager.new(klass)
      indexer = Elasticsearch::Rails::HA::ParallelIndexer.new(
        klass: stager.klass,
        idx_name: (ENV['INDEX'] || stager.tmp_index_name),
        nprocs: nprocs.to_i,
        batch_size: batch_size.to_i,
        max: max,
        scope: ENV.fetch('SCOPE', nil),
        force: true,
        verbose: !ENV['QUIET']
      )
      indexer.run
      stager.alias_stage_to_tmp_index
      puts "[#{Time.now.utc.iso8601}] #{klass} index staged as #{stager.stage_index_name}"
    end

    desc "promote staged index to live"
    task :promote do
      klass = ENV['CLASS'] or fail "CLASS required"
      stager = Elasticsearch::Rails::HA::IndexStager.new(klass)
      stager.promote(ENV['INDEX'])
      puts "[#{Time.now.utc.iso8601}] #{klass} promoted #{stage_index_name} to #{stager.live_index_name}"
    end

  end
end
