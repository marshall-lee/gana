module Gana
  module EventedState
    def initialize(*)
      @evs_mutex = Mutex.new
      @evs_cond = ConditionVariable.new
      super
    end

    def state!(value)
      @evs_mutex.synchronize do
        @state = value
        @evs_cond.signal
      end
    end

    def wait_until(timeout = nil)
      @evs_mutex.synchronize do
        @evs_cond.wait(@evs_mutex, timeout) until yield self
      end
    end

    def wait_while(timeout = nil)
      @evs_mutex.synchronize do
        @evs_cond.wait(@evs_mutex, timeout) while yield self
      end
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
