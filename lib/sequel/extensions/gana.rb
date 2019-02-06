require 'gana'

# :nodoc
module Gana
  module SequelDbExtension
    def gana(&block)
      Runner.new(self, &block)
    end

    def log_connection_yield(sql, conn, args=nil, &block)
      if (worker = Thread.current[:gana_worker])
        statement = Statement.new(sql, worker)
        timer = Sequel.start_timer
        worker.runner.log << statement
      end
      super.tap { statement.status = :succeed if statement }
    rescue => e
      statement.status = :failed if statement
      raise
    ensure
      if statement && !e
        statement.duration = Sequel.elapsed_seconds_since(timer)
      end
    end

    Sequel::Database.register_extension :gana, self
  end
end
