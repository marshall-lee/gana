module Gana
  class Barrier
    def initialize(*workers)
      @mutex = Mutex.new
      @cond = ConditionVariable.new
      @workers = workers
      @worker_set = Set.new
    end

    def wait(timeout = nil)
      @mutex.synchronize do
        @worker_set << Gana::Worker.current
        if all_passed?
          @cond.broadcast
        else
          @cond.wait(@mutex, timeout)
          if !all_passed?
            raise "fooo"
          end
        end
      end
    end

    private

    def all_passed?
      @worker_set.include?(*workers)
    end
  end
end
