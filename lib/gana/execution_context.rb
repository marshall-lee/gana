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
      name = "#{name}_#{Process.pid}_#{SecureRandom.hex(3)}".to_sym
      db.create_table(name, &block)
      db.primary_key(name) # Prevent primary key fetching in workers.
      @runner.tmp_tables << name
      db[name]
    end

    def begin_transaction(*args)
      if (worker = Gana::Worker.current)
        worker.begin_transaction(*args)
      else
        raise 'Cannot begin_transaction outside of worker thread'
      end
    end

    def commit_transaction(*args)
      if (worker = Gana::Worker.current)
        worker.commit_transaction(*args)
      else
        raise 'Cannot commit_transaction outside of worker thread'
      end
    end

    def rollback_transaction(*args)
      if (worker = Gana::Worker.current)
        worker.rollback_transaction(*args)
      else
        raise 'Cannot rollback_transaction outside of worker thread'
      end
    end

    def savepoint(*args)
      if (worker = Gana::Worker.current)
        worker.savepoint(*args)
      else
        raise 'Cannot set savepoint outside of worker thread'
      end
    end
  end
end
