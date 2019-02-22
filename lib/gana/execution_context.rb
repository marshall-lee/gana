module Gana
  require 'delegate'
  require 'securerandom'

  class ExecutionContext < DelegateClass(Sequel::Database)
    def initialize(runner, &block)
      @runner = runner
      super(@runner.db)
      instance_exec(*@runner.workers, &block)
    end

    def print(msg)
      @runner.log << LogPrint.new(Gana::Worker.current, msg)
    end

    def sync_all
      @runner.workers.each(&:sync)
    end

    def db
      @runner.db
    end

    def log
      @runner.log.each
    end

    def new_table(name = :table, &block)
      name = "#{name}_#{SecureRandom.hex(3)}".to_sym
      db.create_table(name, &block)
      @runner.tmp_tables << name
      db[name]
    end

    def begin_transaction(*args)
      if Gana::Worker.current
        Gana::Worker.current.begin_transaction(*args)
      else
        raise 'Cannot begin_transaction outside of worker thread'
      end
    end

    def commit_transaction(*args)
      if Gana::Worker.current
        Gana::Worker.current.commit_transaction(*args)
      else
        raise 'Cannot commit_transaction outside of worker thread'
      end
    end

    def rollback_transaction(*args)
      if Gana::Worker.current
        Gana::Worker.current.rollback_transaction(*args)
      else
        raise 'Cannot rollback_transaction outside of worker thread'
      end
    end

    def savepoint(*args)
      if Gana::Worker.current
        Gana::Worker.current.savepoint(*args)
      else
        raise 'Cannot set savepoint outside of worker thread'
      end
    end
  end
end
