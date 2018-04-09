module Gana
  class LogPrint
    def initialize(worker, msg)
      @worker = worker
      @msg = msg
    end

    attr_reader :worker, :msg
  end
end
