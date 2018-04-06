module Gana
  class Statement
    def initialize(sql, worker)
      @sql = sql
      @worker = worker
      @status = :running
    end

    attr_reader :sql, :worker
    attr_accessor :status, :duration
  end
end
