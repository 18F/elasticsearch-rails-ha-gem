require 'elasticsearch/index_stager'

module Elasticsearch
  module Rails
    module HA
      class IndexStager < Elasticsearch::IndexStager
        attr_reader :klass, :live_index_name

        def initialize(klass)
          @klass = klass.constantize
          @index_name = @klass.index_name
          @es_client = @klass.__elasticsearch__.client
        end

        def stage_index_name
          if klass.respond_to?(:stage_index_name)
            klass.stage_index_name
          else
            index_name + "_staged"
          end
        end
      end
    end
  end
end
