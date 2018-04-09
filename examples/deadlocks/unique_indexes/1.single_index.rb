# Unique index could be dangerous when multiple transactions
# attempt to write same values concurrently.
#
# More info: https://rcoh.svbtle.com/postgres-unique-constraints-can-cause-deadlock

gana do |tx1, tx2|
  table = new_table :lol do
    primary_key :id
    column :key, :text, unique: true
  end

  [tx1, tx2].each(&:begin_transaction)

  tx1.sync { table.insert(key: 'foo') }
  tx2.sync { table.insert(key: 'bar') }

  tx1.exec { table.insert(key: 'bar') }
  tx2.exec { table.insert(key: 'foo') }

  [tx1, tx2].each(&:commit_transaction)
end
