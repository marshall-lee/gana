RSpec.describe Gana do
  it 'allocates number workers according to block arity' do
    db.gana do |t|
      expect(t).to be_kind_of Gana::Worker
    end

    db.gana do |t1, t2|
      expect(t1).to be_kind_of Gana::Worker
      expect(t2).to be_kind_of Gana::Worker
    end
  end

  it 'raises an error on ambiguous block arity' do
    expect { db.gana { |*_args| } }.to raise_error(ArgumentError)
    expect { db.gana { |a, *_args| } }.to raise_error(ArgumentError)
    expect { db.gana { |a, b, *_args| } }.to raise_error(ArgumentError)
  end

  describe '#print' do
    it 'adds messages to log' do
      runner = db.gana do
        print 'foo'
        print 'bar'
      end
      expect(runner.log.take(2)).to match [
        a_kind_of(Gana::LogPrint).and(
          an_object_having_attributes(msg: 'foo')
        ),
        a_kind_of(Gana::LogPrint).and(
          an_object_having_attributes(msg: 'bar')
        )
      ]
    end

    it 'tags record with current worker' do
      runner = db.gana do |t1, t2|
        print 'foo'
        t1.sync { print 'bar' }
        t2.sync { print 'baz' }

        expect(log.take(3)).to match [
          a_kind_of(Gana::LogPrint).and(
            an_object_having_attributes(worker: nil, msg: 'foo')
          ),
          a_kind_of(Gana::LogPrint).and(
            an_object_having_attributes(worker: t1, msg: 'bar')
          ),
          a_kind_of(Gana::LogPrint).and(
            an_object_having_attributes(worker: t2, msg: 'baz')
          )
        ]
      end
      expect(runner).not_to have_log_errors
    end
  end

  describe '#new_table' do
    it 'creates new tables' do
      runner = db.gana do
        expect { new_table }
          .to change { db.tables.count }.by 1
        expect { new_table }
          .to change { db.tables.count }.by 1
      end
      expect(runner).not_to have_log_errors
    end

    it 'releases created tables' do
      expect do
        runner = db.gana do
          new_table
          new_table
        end
        expect(runner).not_to have_log_errors
      end.not_to change { db.tables.count }
    end

    it 'customizes table name' do
      runner = db.gana do
        ds = new_table
        expect(ds.first_source_table).to start_with('table_')
        ds = new_table(:foo)
        expect(ds.first_source_table).to start_with('foo_')
        ds = new_table(:bar)
        expect(ds.first_source_table).to start_with('bar_')
      end
      expect(runner).not_to have_log_errors
    end
  end

  it 'logs SQL statements' do
    runner = db.gana do |t1, t2|
      t1.sync { select(1).all }
      t2.sync { select(2).all }
      expect(log.take(2)).to match [
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+1/, worker: t1)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+2/, worker: t2)
        )
      ]
    end
    expect(runner).not_to have_log_errors
  end

  it 'measures statement execution time' do
    runner = db.gana do |t1, t2, t3|
      t1.exec { execute 'SELECT pg_sleep(0.3)' }
      t2.exec { execute 'SELECT pg_sleep(0.1)' }
      t3.exec { execute 'SELECT pg_sleep(0.2)' }

      sync_all

      expect(log).to match a_collection_containing_exactly(
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(worker: t1,
                                      duration: a_value_within(0.3).of(0.1))
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(worker: t2,
                                      duration: a_value_within(0.1).of(0.1))
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(worker: t3,
                                      duration: a_value_within(0.2).of(0.1))
        )
      )
    end
    expect(runner).not_to have_log_errors
  end

  context 'on errors' do
    it 'logs errors' do
      runner = db.gana do |t|
        t.exec { raise 'FOO' }
      end
      expect(runner.log.first).to match a_kind_of(Gana::LogError).and(
        an_object_having_attributes(
          worker: a_kind_of(Gana::Worker),
          error: an_instance_of(RuntimeError).and(
            an_object_having_attributes(message: 'FOO')
          )
        )
      )

      error_class = Class.new(StandardError)
      runner = db.gana do |t|
        t.exec { raise error_class, 'BAR' }
      end
      expect(runner.log.first).to match a_kind_of(Gana::LogError).and(
        an_object_having_attributes(
          worker: a_kind_of(Gana::Worker),
          error: an_instance_of(error_class).and(
            an_object_having_attributes(message: 'BAR')
          )
        )
      )
    end

    it 'does not log system errors' do
      runner = db.gana do |t|
        t.exec { Thread.current.kill }
      end
      expect(runner.log.count).to eq 0
    end

    it 'logs error raised outside of worker' do
      runner = db.gana do |_|
        raise 'FOO'
      end
      expect(runner.log.first).to match a_kind_of(Gana::LogError).and(
        an_object_having_attributes(
          error: an_instance_of(RuntimeError).and(
            an_object_having_attributes(message: 'FOO')
          )
        )
      )
    end

    it 'terminates every worker' do
      runner = db.gana do |t1, t2|
        t1.exec { execute 'SELECT pg_sleep(0.01)' }
        t2.sync { print 'foo' }
        t2.sync { fail }
        t1.sync { print 'bar' }
        t2.sync { print 'baz' }
      end
      expect(runner.log.count).to eq 3
      expect(runner.workers[0]).to_not be_alive
      expect(runner.workers[1]).to_not be_alive
    end
  end

  describe '#begin_transaction' do
    it 'executes a BEGIN statement' do
      runner = db.gana do |t|
        t.begin_transaction
      end
      expect(runner.log.first).to match a_kind_of(Gana::Statement).and(
        an_object_having_attributes(sql: 'BEGIN')
      )
      expect(runner).not_to have_log_errors
    end

    it 'allows to set the isolation level' do
      runner = db.gana do |t|
        t.begin_transaction(isolation: :serializable)
      end
      expect(runner.log.take(2)).to match [
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: 'BEGIN')
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: 'SET TRANSACTION ISOLATION LEVEL SERIALIZABLE')
        )
      ]
    end

    it 'forbids nested transactions' do
      runner = db.gana do |t|
        t.begin_transaction
        t.begin_transaction
      end
      expect(runner.log.take(3)).to match [
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: 'BEGIN')
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: 'ROLLBACK')
        ),
        a_kind_of(Gana::LogError).and(
          an_object_having_attributes(
            error: a_kind_of(RuntimeError).and(
              an_object_having_attributes(message: 'Transaction is already started')
            )
          )
        )
      ]
    end

    it 'could be executed inside #exec actions' do
      runner = db.gana do |t|
        t.exec { select(0).all }
        t.exec do
          select(1).all
          begin_transaction
          select(2).all
        end
        t.exec { select(3).all }
        sync_all
      end
      expect(runner.log.take(5)).to match [
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+0/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+1/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: 'BEGIN')
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+2/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+3/)
        )
      ]
    end

    it 'cannot be called without worker context' do
      runner = db.gana do |_|
        begin_transaction
      end
      expect(runner.log.first).to match a_kind_of(Gana::LogError).and(
        an_object_having_attributes(
          error: a_kind_of(RuntimeError).and(
            an_object_having_attributes(message: "Cannot begin_transaction outside of worker thread")
          )
        )
      )
    end
  end

  describe '#commit_transaction' do
    it 'executes a COMMIT statement' do
      runner = db.gana do |t|
        t.begin_transaction
        t.commit_transaction
      end
      expect(runner.log.take(2)).to match [
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: 'BEGIN')
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: 'COMMIT')
        )
      ]
      expect(runner).not_to have_log_errors
    end

    it 'cannot be called outside of transaction' do
      runner = db.gana do |t|
        t.commit_transaction
      end
      expect(runner.log.first).to match a_kind_of(Gana::LogError).and(
        an_object_having_attributes(
          error: a_kind_of(RuntimeError).and(
            an_object_having_attributes(message: "Cannot commit_transaction because it's not started")
          )
        )
      )
    end

    it 'could be executed inside #exec actions' do
      runner = db.gana do |t|
        t.exec { select(0).all }
        t.exec do
          select(1).all
          begin_transaction
          select(2).all
          commit_transaction
          select(3).all
        end
        t.exec { select(4).all }
        sync_all
      end
      expect(runner.log.take(7)).to match [
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+0/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+1/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: 'BEGIN')
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+2/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: 'COMMIT')
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+3/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+4/)
        )
      ]
    end

    it 'cannot be called without worker context' do
      runner = db.gana do |_|
        commit_transaction
      end
      expect(runner.log.first).to match a_kind_of(Gana::LogError).and(
        an_object_having_attributes(
          error: a_kind_of(RuntimeError).and(
            an_object_having_attributes(message: 'Cannot commit_transaction outside of worker thread')
          )
        )
      )
    end
  end

  describe '#rollback_transaction' do
    it 'executes ROLLBACK statement' do
      runner = db.gana do |t|
        t.begin_transaction
        t.rollback_transaction
      end
      expect(runner.log.take(2)).to match [
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql:'BEGIN')
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: 'ROLLBACK')
        )
      ]
      expect(runner).not_to have_log_errors
    end

    it 'cannot be called outside of transaction' do
      runner = db.gana do |t|
        t.rollback_transaction
      end
      expect(runner.log.first).to match a_kind_of(Gana::LogError).and(
        an_object_having_attributes(
          error: a_kind_of(RuntimeError).and(
            an_object_having_attributes(message: "Cannot rollback_transaction because it's not started")
          )
        )
      )
    end

    it 'could be executed inside #exec actions' do
      runner = db.gana do |t|
        t.exec { db.select(0).all }
        t.exec do
          db.select(1).all
          begin_transaction
          db.select(2).all
          rollback_transaction
          db.select(3).all
        end
        t.exec { db.select(4).all }
      end
      expect(runner.log.take(7)).to match [
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+0/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+1/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: 'BEGIN')
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+2/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /ROLLBACK/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+3/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+4/)
        )
      ]
    end

    it 'cannot be called without worker context' do
      runner = db.gana do |_|
        rollback_transaction
      end
      expect(runner.log.first).to match a_kind_of(Gana::LogError).and(
        an_object_having_attributes(
          error: a_kind_of(RuntimeError).and(
            an_object_having_attributes(message: 'Cannot rollback_transaction outside of worker thread')
          )
        )
      )
    end
  end

  describe '#savepoint' do
    it 'executes a SAVEPOINT statement' do
      runner = db.gana do |t|
        t.begin_transaction
        t.savepoint
      end
      expect(runner.log.take(2)).to match [
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: 'BEGIN')
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SAVEPOINT/)
        )
      ]
    end

    it 'cannot be called outside of transaction' do
      runner = db.gana do |t|
        t.savepoint
      end
      expect(runner.log.first).to match a_kind_of(Gana::LogError).and(
        an_object_having_attributes(
          error: a_kind_of(RuntimeError).and(
            an_object_having_attributes(message: 'Savepoint can only be used inside transaction')
          )
        )
      )
    end

    it 'allows nested savepoints' do
      runner = db.gana do |t|
        t.begin_transaction
        t.savepoint
        t.savepoint
      end
      expect(runner.log.take(3)).to match [
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: 'BEGIN')
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SAVEPOINT/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SAVEPOINT/)
        )
      ]
    end

    it 'could be executed inside #exec actions' do
      runner = db.gana do |t|
        t.exec { select(0).all }
        t.exec do
          select(1).all
          begin_transaction
          select(2).all
          savepoint
          select(3).all
        end
        t.exec { select(4).all }
        sync_all
      end
      expect(runner.log.take(7)).to match [
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+0/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+1/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: 'BEGIN')
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+2/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SAVEPOINT/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+3/)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+4/)
        )
      ]
    end

    it 'cannot be called without worker context' do
      runner = db.gana do |_|
        savepoint
      end
      expect(runner.log.first).to match a_kind_of(Gana::LogError).and(
        an_object_having_attributes(
          error: a_kind_of(RuntimeError).and(
            an_object_having_attributes(message: 'Cannot set savepoint outside of worker thread')
          )
        )
      )
    end
  end
end
