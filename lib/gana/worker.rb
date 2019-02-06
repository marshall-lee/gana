module Gana
  class Worker
    LAME_TIMEOUT = 0.05

    def initialize(runner, index)
      @runner = runner
      @index = index
      @queue = Queue.new
      @thread = Thread.new { run }
    end

    def sync(&block)
      exec(&block).tap do |action|
        action.wait_until(&:completed?)
      end
    end

    def exec(&block)
      Actions::Exec.new(&block).tap do |action|
        @queue << action
        action.wait_while(LAME_TIMEOUT, &:waiting?)
      end
    end

    def begin_transaction(**options)
      @queue << Actions::BeginTransaction.new(**options)
    end

    def commit_transaction
      @queue << Actions::CommitTransaction.new
    end

    def rollback_transaction
      @queue << Actions::RollbackTransaction.new
    end

    def terminate
      @queue.close
      @thread.join
    end

    def alive?
      @thread.alive?
    end

    attr_reader :runner, :index

    private

    def db
      @runner.db
    end

    def run
      db.synchronize do
        Thread.current[:gana_worker] = self
        begin
          run_loop
        rescue => e
          @runner.log << LogError.new(self, e)
        end
      end
    end

    def run_loop
      until @queue.closed? && @queue.empty?
        action = @queue.pop
        case action
        when Actions::Exec
          action.run
          raise action.result if action.state == :failed
        when Actions::BeginTransaction
          db.transaction(action.options) { run_loop }
        when Actions::RollbackTransaction
          raise Sequel::Rollback
        when Actions::CommitTransaction
          if db.in_transaction?
            break
          else
            raise "Cannot commit_transaction because it's not started"
          end
        when nil
          @terminated = true
        end
      end
    end
  end
end
