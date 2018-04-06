begin
  drop_table? :lol
  gana do |t1, t2|
    t1.sync do
      create_table :lol do
        column :key1, :text
        index :key1, unique: true
      end
    end

    table = self[:lol]

    t1.begin_transaction
    t1.sync { table.insert(key1: 'foo') }

    t2.begin_transaction
    t2.exec { table.insert(key1: 'foo') }

    sleep 2

    t1.commit_transaction
    t2.commit_transaction
  end
ensure
  drop_table? :lol
end
