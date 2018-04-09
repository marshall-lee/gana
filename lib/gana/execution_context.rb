module Gana
  require 'delegate'

  class ExecutionContext < DelegateClass(Sequel::Database)
    def initialize(runner)
      @runner = runner
      super(@runner.db)
    end

    def print(msg)
      @runner.log << LogPrint.new(Thread.current[:gana_worker], msg)
    end
  end
end
