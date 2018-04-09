# Or even more indexes

gana do |t1, t2, t3|
  table = new_table do
    primary_key :id
    column :key1, :text, unique: true
    column :key2, :text, unique: true
    column :key3, :text, unique: true
  end

  [t1, t2, t3].each(&:begin_transaction)

  t1.sync { table.insert(key1: 'foo') }
  t2.sync { table.insert(key2: 'bar') }
  t3.sync { table.insert(key3: 'baz') }

  t1.exec { table.insert(key2: 'bar') }
  t2.exec { table.insert(key3: 'baz') }
  t3.exec { table.insert(key1: 'foo') }

  [t1, t2, t3].each(&:commit_transaction)
end
