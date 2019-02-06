module Gana::Actions
  # :nodoc
  class Exec
    include Gana::EventedState

    def initialize(&block)
      super
      @block = block || proc {}
      @state = :waiting
      @result = nil
    end

    def run
      state!(:running)
      @block.call.tap do |result|
        @result = result
        state!(:succeed)
      end
    rescue => e
      @result = e
      state!(:failed)
    end

    attr_reader :result

    def waiting?
      @state == :waiting
    end

    def completed?
      @state == :succeed || @state == :failed
    end
  end
end
