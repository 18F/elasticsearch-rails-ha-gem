require 'ansi'

module Elasticsearch
  module Rails
    module HA
      class ParallelIndexer

        attr_reader :klass, :idx_name, :nprocs, :batch_size, :max, :force, :verbose, :scope

        # leverage multiple cores to run indexing in parallel
        def initialize(opts)
          @klass    = opts[:klass] or fail "klass required"
          @idx_name = opts[:idx_name] or fail "idx_name required"
          @nprocs   = opts[:nprocs] or fail "nprocs required"
          @batch_size = opts[:batch_size] or fail "batch_size required"
          @max        = opts[:max]
          @force      = opts[:force]
          @verbose    = opts[:verbose]
          @scope      = opts[:scope]

          # calculate array of offsets based on nprocs
          @total_expected = klass.count
          @pool_size = (@total_expected / @nprocs.to_f).ceil
        end

        def run
          # get all ids since we can't assume there are no holes in the PK sequencing
          ids = klass.order('id ASC').pluck(:id)
          offsets = []
          ids.each_slice(@pool_size) do |chunk|
            #puts "chunk: size=#{chunk.size} #{chunk.first}..#{chunk.last}"
            offsets.push( chunk.first )
          end
          if @verbose
            puts ::ANSI.blue{ "Parallel Indexer: index=#{@idx_name} total=#{@total_expected} nprocs=#{@nprocs} pool_size=#{@pool_size} offsets=#{offsets} " }
          end

          if @force
            @verbose and puts ::ANSI.blue{ "Force creating new index" }
            klass.__elasticsearch__.create_index! force: true, index: idx_name
            klass.__elasticsearch__.refresh_index! index: idx_name
          end

          @current_db_config = ActiveRecord::Base.connection_config
          # IMPORTANT before forks in offsets loop
          ActiveRecord::Base.connection.disconnect!

          child_pids = []
          offsets.each do |start_at|
            child_pid = fork do
              run_child(start_at)
            end
            if child_pid
              child_pids << child_pid
            end
          end

          # reconnect in parent
          ActiveRecord::Base.establish_connection(@current_db_config)

          # Process.waitall seems to hang during tests. Do it manually.
          child_results = []

          child_pids.each do |pid|
            Process.wait(pid)
            child_results.push [pid, $?]
          end

          process_child_results(child_results)
        end

        def process_child_results(results)
          # check exit status of each child so we know if we should throw exception
          results.each do |pair|
            pid = pair[0]
            pstat = pair[1]
            exit_ok = true
            if pstat.exited?
              @verbose and puts ::ANSI.blue{ "PID #{pid} exited with #{pstat.exitstatus}" }
            end
            if pstat.signaled?
              puts ::ANSI.red{ " >> #{pid} exited with uncaught signal #{pstat.termsig}" }
              exit_ok = false
            end

            if !pstat.success?
              puts ::ANSI.red{ " >> #{pid} was not successful" }
              exit_ok = false
            end

            if pair[1].exitstatus != 0
              puts ::ANSI.red{ " >> #{pid} exited with non-zero status" }
              exit_ok = false
            end

            if !exit_ok
              raise ::ANSI.red{ "PID #{pair[0]} exited abnormally, so the whole reindex fails" }
            end
          end
        end

        def run_child(start_at)
          # IMPORTANT after fork
          ActiveRecord::Base.establish_connection(@current_db_config)

          # IMPORTANT for tests to determine whether at_end should run
          ENV["I_AM_HA_CHILD"] = "true"

          completed = 0
          errors    = []
          @verbose and puts ::ANSI.blue{ "Start worker #{$$} at offset #{start_at}" }
          pbar = ::ANSI::Progressbar.new("#{klass} [#{$$}]", @pool_size, STDOUT) rescue nil
          checkpoint = false
          if pbar
            pbar.__send__ :show
            pbar.bar_mark = '='
          else
            checkpoint = true
          end

          @klass.__elasticsearch__.import return: 'errors',
            index: @idx_name,
            start: start_at,
            scope: @scope,
            batch_size: @batch_size    do |resp|
              # show errors immediately (rather than buffering them)
              errors += resp['items'].select { |k, v| k.values.first['error'] }
              completed += resp['items'].size
              if pbar && @verbose
                pbar.inc resp['items'].size
              end
              if checkpoint && @verbose
                puts ::ANSI.blue{ "[#{$$}] #{Time.now.utc.iso8601} : #{completed} records completed" }
              end
              STDERR.flush
              STDOUT.flush
              if errors.size > 0
                STDOUT.puts "ERRORS in #{$$}:"
                STDOUT.puts pp(errors)
              end
              if completed >= @pool_size || (@max && @max.to_i == completed)
                pbar.finish if pbar
                @verbose and puts ::ANSI.blue{ "Worker #{$$} finished #{completed} records" }
                exit!(true) # exit child worker
              end
            end # end do |resp| block
        end

      end
    end
  end
end
