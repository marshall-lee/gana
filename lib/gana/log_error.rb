module Gana
  class LogError
    def initialize(worker, error)
      @worker = worker
      @error = error
    end

    attr_reader :worker, :error
  end
end
