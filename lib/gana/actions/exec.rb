module Gana::Actions
  # :nodoc
  class Exec < Base
    include Gana::EventedState

    def initialize(&block)
      super()
      @block = block || proc {}
      @state = :waiting
      @result = nil
    end

    def run
      # We need to initialize fiber here to associate fiber with worker thread.
      @fiber ||= Fiber.new do
        Thread.current[:gana_current_exec] = self
        @block.call
      end
      state!(:running)
      result = @fiber.resume
      if @fiber.alive?
        state!(:paused)
        return result
      else
        @result = result
        state!(:succeed)
      end
    rescue => e
      @result = e
      state!(:failed)
      raise
    end

    attr_reader :result

    def waiting?
      @state == :waiting
    end

    def paused?
      @state == :paused
    end

    def sql?
      @state == :sql
    end

    def failed?
      @state == :failed
    end

    def completed?
      @state == :succeed || @state == :failed
    end
  end
end
