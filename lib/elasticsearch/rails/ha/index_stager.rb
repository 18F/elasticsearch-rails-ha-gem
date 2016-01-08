module Elasticsearch
  module Rails
    module HA
      class IndexStager
        attr_reader :klass, :live_index_name

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
          @_suffix ||= Time.now.strftime('%Y%m%d%H%M%S') + '-' + SecureRandom.hex[0..8]
          "#{klass.index_name}_#{@_suffix}"
        end

        def alias_stage_to_tmp_index
          es_client.indices.delete index: stage_index_name rescue false
          es_client.indices.update_aliases body: {
            actions: [
              { add: { index: tmp_index_name, alias: stage_index_name } }
            ]
          }
        end

        def clean_up_old_indices(age_window=1.weeks.ago)
          old_aliases = es_client.indices.get_aliases(index: stage_index_name).keys
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

        def promote(live_index_name=klass.index_name)
          @live_index_name = live_index_name

          # the renaming actions (performed atomically by ES)
          rename_actions = [
            { remove: { index: stage_aliased_to, alias: stage_index_name } },
            {    add: { index: stage_index_name, alias: live_index_name } }
          ]

          # zap any existing index known as index_name,
          # but do it conditionally since it is reasonable that it does not exist.
          to_delete = []
          existing_live_index = es_client.indices.get_aliases(index: live_index_name)
          existing_live_index.each do |k,v|

            # if the index is merely aliased, remove its alias as part of the aliasing transaction.
            if k != klass.index_name
              rename_actions.unshift({ remove: { index: k, alias: live_index_name } })

              # mark it for deletion when we've successfully updated aliases
              to_delete.push k

            else
              # this is a real, unaliased index with this name, so it must be deleted.
              # (This usually happens the first time we implement the aliasing scheme against
              # an existing installation.)
              es_client.indices.delete index: live_index_name rescue false
            end
          end

          # re-alias
          es_client.indices.update_aliases body: { actions: rename_actions }

          # clean up
          to_delete.each do |idxname|
            es_client.indices.delete index: idxname rescue false
          end
        end

        private

        def tmp_index_pattern
          /#{klass.index_name}_(\d{14})-\w{8}$/
        end

        def es_client
          klass.__elasticsearch__.client
        end

        def stage_aliased_to
          # find the newest tmp index to which staged is aliased.
          # we need this because we want to re-alias it.
          aliased_to = nil
          stage_aliases = es_client.indices.get_aliases(index: stage_index_name)
          stage_aliases.each do |k,v|
            aliased_to ||= k
            stage_tstamp = aliased_to.match(tmp_index_pattern)[1]
            k_tstamp = k.match(tmp_index_pattern)[1]
            if Time.parse(stage_tstamp) < Time.parse(k_tstamp)
              aliased_to = k
            end
          end
          if !aliased_to
            raise "Cannot identify index aliased to by '#{stage_index_name}'"
          end
          aliased_to
        end
      end
    end
  end
end
