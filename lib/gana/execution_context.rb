module Gana
  require 'delegate'

  class ExecutionContext < DelegateClass(Sequel::Database)
    def initialize(runner)
      @runner = runner
      super(@runner.db)
    end
  end
end
