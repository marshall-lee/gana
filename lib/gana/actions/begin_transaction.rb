module Gana::Actions
  class BeginTransaction
    def initialize(**options)
      @options = options
    end

    attr_reader :options
  end
end
