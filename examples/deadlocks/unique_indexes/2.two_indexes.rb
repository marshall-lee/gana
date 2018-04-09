# Unique index deadlock loop can involve two indexes

gana do |t1, t2|
  table = new_table do
    primary_key :id
    column :key1, :text, unique: true
    column :key2, :text, unique: true
  end

  [t1, t2].each(&:begin_transaction)

  t1.sync { table.insert(key1: 'foo') }
  t2.sync { table.insert(key2: 'bar') }

  t1.exec { table.insert(key2: 'bar') }
  t2.exec { table.insert(key1: 'foo') }

  [t1, t2].each(&:commit_transaction)
end
