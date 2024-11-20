module Gana
  module EventedState
    def initialize
      @evs_mutex = Mutex.new
      @evs_cond = ConditionVariable.new
      super
    end

    def state!(value)
      @evs_mutex.synchronize do
        @state = value
        @evs_cond.broadcast
      end
    end

    def wait_until(timeout = nil)
      @evs_mutex.synchronize do
        unless timeout
          loop do
            return true if yield self

            @evs_cond.wait(@evs_mutex)
          end
        else
          was = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          loop do
            return true if yield self

            @evs_cond.wait(@evs_mutex, timeout)
            now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            duration = now - was
            return false if duration >= timeout

            timeout -= duration
            was = now
          end
        end
      end
    end

    def wait_while(timeout = nil)
      wait_until(timeout) { |obj| !yield obj }
    end

    attr_reader :state
  end

  class Event
    include EventedState

    def initialize
      @state = false
      super
    end

    def set!
      state!(true)
    end

    def wait(timeout = nil)
      wait_until(timeout) { @state == true }
    end
  end
end
