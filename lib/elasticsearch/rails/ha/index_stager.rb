module Elasticsearch
  module Rails
    module HA
      class IndexStager
        attr_reader :klass

        def initialize(klass)
          @klass = klass.constantize
        end

        def stage_index_name
          if klass.respond_to?(:stage_index_name)
            klass.stage_index_name
          else
            klass.index_name + "_stage"
          end
        end

        def tmp_index_name
          @_suffix ||= Time.now.strftime('%Y%m%d%H%M%S') + SecureRandom.hex[0..8]
          "#{klass.index_name}_#{@_suffix}"
        end

        def alias_index
          es_client.indices.delete index: stage_index_name rescue false
          es_client.indices.update_aliases body: {
            actions: [
              { add: { index: tmp_index_name, alias: stage_index_name } }
            ]
          } 
        end

        def clean_up_old_indices(age_window)
          old_aliases = es_client.indices.get_aliases(index: stage_idx_name).keys
          tmp_index_pattern = /#{klass.index_name}_(\d{8})\w{8}$/
          old_aliases.each do |alias_name|
            next unless alias_name.match(tmp_index_pattern)
            begin
              if Time.parse(alias_name.match(tmp_index_pattern)[1]) < age_window
                es_client.indices.delete index: alias_name
                puts "Cleaned up old alias #{alias_name}"
              end
            rescue => err
              puts "Failed to clean up alias #{alias_name}: #{err}"
            end
          end
        end

        def promote

        end

        private

        def es_client
          klass.__elasticsearch__.client
        end
      end
    end
  end
end
