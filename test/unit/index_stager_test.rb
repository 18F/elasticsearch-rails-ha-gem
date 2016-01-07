require 'test_helper'

module Elasticsearch
  module Test
    class IndexStager < ::Test::Unit::TestCase
      context "IndexStager" do
        setup do
          ActiveRecord::Base.raise_in_transactional_callbacks = true
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
        end

        should "generate index names" do
          stager = Elasticsearch::Rails::HA::IndexStager.new('Article')
          assert_equal stager.stage_index_name, "articles_stage", "stage_index_name"
          assert_match /articles_\d{8}\w{8}/, stager.tmp_index_name, "tmp_index_name"
        end

      end
    end
  end
end
