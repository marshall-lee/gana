# Or even multiple tables

gana do |t1, t2|
  lol = new_table :lol do
    primary_key :id
    column :key1, :text, unique: true
  end

  rofl = new_table :rofl do
    primary_key :id
    column :key2, :text, unique: true
  end

  [t1, t2].each(&:begin_transaction)

  t1.sync { lol.insert(key1: 'foo') }
  t2.sync { rofl.insert(key2: 'bar') }

  t1.exec { rofl.insert(key2: 'bar') }
  t2.exec { lol.insert(key1: 'foo') }

  [t1, t2].each(&:commit_transaction)
end
