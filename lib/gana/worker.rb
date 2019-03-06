module Gana
  class Worker
    LAME_TIMEOUT = 0.005

    class << self
      def current
        Thread.current.thread_variable_get(:gana_current_worker)
      end
    end

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
      run_action(Actions::Exec.new(&block)) do |action|
        action.wait_while(LAME_TIMEOUT, &:waiting?)
        @thread.join if action.failed?
      end
    end

    def begin_transaction(isolation: nil)
      exec_action = Thread.current[:gana_current_exec]

      action = Actions::BeginTransaction.new(db, isolation: isolation) do
        handle_action(exec_action)
        run_loop
      end

      if exec_action
        Fiber.yield action
      else
        run_action(action) do
          action.wait_until(&:completed?)
          @thread.join if action.failed?
        end
      end
    end

    def commit_transaction
      exec_action = Thread.current[:gana_current_exec]

      action = Actions::CommitTransaction.new(db, exec_action)

      if exec_action
        Fiber.yield(action)
      else
        run_action(action) do
          action.wait_until(&:completed?)
          @thread.join if action.failed?
        end
      end
    end

    def rollback_transaction
      exec_action = Thread.current[:gana_current_exec]

      action = Actions::RollbackTransaction.new(db, exec_action)

      if exec_action
        Fiber.yield(action)
      else
        run_action(action) do
          action.wait_until(&:completed?)
          @thread.join if action.failed?
        end
      end
    end

    def savepoint
      exec_action = Thread.current[:gana_current_exec]

      action = Actions::Savepoint.new(db) do
        handle_action(exec_action)
        run_loop
      end

      if exec_action
        Fiber.yield action
      else
        run_action(action) do
          action.wait_until(&:completed?)
          @thread.join if action.failed?
        end
      end
    end

    def join
      @thread.join
    end

    def terminate
      @queue.close
    end

    def terminated?
      @queue.closed?
    end

    def alive?
      @thread.alive?
    end

    attr_reader :runner, :index

    private

    def db
      @runner.db
    end

    def run_action(action)
      @queue << action
      yield action if block_given?
      action
    rescue ClosedQueueError
      # It's useless to pre-check _@queue.closed?_ before _@queue <<_ because of
      # possible race condition.
    ensure
      # If one of the workers terminated, execution of the main block
      # should not go further.
      throw :terminate if terminated?
    end

    def run
      db.synchronize do
        Thread.current.thread_variable_set(:gana_current_worker, self)
        begin
          run_loop
        rescue => e
          @runner.log << LogError.new(self, e)
          runner.terminate_all
        end
      end
    end

    def run_loop
      until terminated? && @queue.empty?
        action = @queue.pop
        handle_action(action)
      end
    end

    def handle_action(action)
      while action
        result = action.run
        action = result.is_a?(Gana::Actions::Base) && result
      end
    end
  end
end
