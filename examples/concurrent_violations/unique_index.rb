gana do |t1, t2|
  table = new_table do
    column :key, :text
    index :key, unique: true
  end

  t1.begin_transaction
  t1.sync { table.insert(key: 'foo') }

  t2.begin_transaction
  t2.exec { table.insert(key: 'foo') }

  sleep 2

  t1.commit_transaction
  t2.commit_transaction
end
