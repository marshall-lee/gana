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
      db.gana do
        print 'foo'
        print 'bar'

        expect(log).to match [
          a_kind_of(Gana::LogPrint).and(
            an_object_having_attributes(msg: 'foo')
          ),
          a_kind_of(Gana::LogPrint).and(
            an_object_having_attributes(msg: 'bar')
          )
        ]
      end
    end

    it 'tags record with current worker' do
      db.gana do |t1, t2|
        print 'foo'
        t1.sync { print 'bar' }
        t2.sync { print 'baz' }

        expect(log).to match [
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
    end
  end

  describe '#new_table' do
    it 'creates new tables' do
      db.gana do
        expect { new_table }
          .to change { db.tables.count }.by 1
        expect { new_table }
          .to change { db.tables.count }.by 1
      end
    end

    it 'releases created tables' do
      expect do
        db.gana do
          new_table
          new_table
        end
      end.not_to change { db.tables.count }
    end

    it 'customizes table name' do
      db.gana do
        ds = new_table
        expect(ds.first_source_table).to start_with('table_')
        ds = new_table(:foo)
        expect(ds.first_source_table).to start_with('foo_')
        ds = new_table(:bar)
        expect(ds.first_source_table).to start_with('bar_')
      end
    end
  end

  it 'logs SQL statements' do
    db.gana do |t1, t2|
      t1.sync { db.select(1).all }
      t2.sync { db.select(2).all }
      expect(log).to match [
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+1/, worker: t1)
        ),
        a_kind_of(Gana::Statement).and(
          an_object_having_attributes(sql: /SELECT.+2/, worker: t2)
        )
      ]
    end
  end

  it 'measures statement execution time' do
    db.gana do |t1, t2, t3|
      t1.exec { execute 'SELECT pg_sleep(0.3)' }
      t2.exec { execute 'SELECT pg_sleep(0.1)' }
      t3.exec { execute 'SELECT pg_sleep(0.2)' }
      sleep 0.35

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
  end
end
