module Gana::Actions
  class Exec
    def initialize(cond, &block)
      @cond = cond
      @block = block
      @status = :waiting
      @result = nil
    end

    def run
      @status = :running
      @block.call.tap do |result|
        @result = result
        @status = :succeed
      end
    rescue => e
      @result = e
      @status = :failed
    ensure
      @cond.signal if @cond
    end

    attr_reader :status, :result
  end
end
