gana do |t1, t2|
  table = new_table :accounts do
    column :acctnum, :integer
    column :balance, :numeric, size: [10, 2]
  end

  t1.sync do
    table.insert(acctnum: 11111, balance: 100.0)
    table.insert(acctnum: 22222, balance: 100.0)
  end

  row1 = table.where(acctnum: 11111)
  row2 = table.where(acctnum: 22222)
  balance = Sequel.identifier(:balance)

  [t1, t2].each(&:begin_transaction)

  t1.exec do
    savepoint
    row1.update(balance: balance + 100)
    bar.wait
    row2.update(balance: balance - 100)
  end

  t2.exec do
    savepoint
    row2.update(balance: balance + 100)
    bar.wait
    row1.update(balance: balance - 100)
  end

  [t1, t2].each(&:commit_transaction)
end
