module Gana
  require 'delegate'
  require 'securerandom'

  class ExecutionContext < DelegateClass(Sequel::Database)
    def initialize(runner)
      @runner = runner
      super(@runner.db)
    end

    def print(msg)
      @runner.log << LogPrint.new(Thread.current[:gana_worker], msg)
    end

    def db
      @runner.db
    end

    def new_table(name = :table, &block)
      name = "#{name}_#{SecureRandom.hex(3)}".to_sym
      db.create_table(name, &block)
      @runner.tmp_tables << name
      db[name]
    end
  end
end
