require 'thread'

module Gana
  class Worker
    def initialize(runner, index)
      @runner = runner
      @index = index
      @queue = Queue.new
      @mutex = Mutex.new
      @thread = Thread.new { run }
    end

    def sync(&block)
      return if @terminated
      @mutex.synchronize do
        cond = ConditionVariable.new
        exec(cond: cond, &block)
        cond.wait(@mutex)
      end
    end

    def exec(cond: nil, &block)
      return if @terminated
      action = Actions::Exec.new(cond, &block)
      @queue << action
      sleep 0.05
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
      @queue << nil
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
      loop do
        break if @terminated
        action = @queue.pop
        case action
        when Actions::Exec
          @mutex.synchronize { action.run }
          raise action.result if action.status == :failed
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
