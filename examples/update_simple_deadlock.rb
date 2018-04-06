begin
  drop_table? :accounts
  gana do |t1, t2|
    t1.sync do
      create_table :accounts do
        column :acctnum, :integer
        column :balance, :numeric, size: [10, 2]
      end
    end

    table = self[:accounts]

    t1.sync do
      table.insert(acctnum: 11111, balance: 100.0)
      table.insert(acctnum: 22222, balance: 100.0)
    end

    row1 = table.where(acctnum: 11111)
    row2 = table.where(acctnum: 22222)
    balance = Sequel.identifier(:balance)

    t1.begin_transaction
    t2.begin_transaction

    t1.sync { row1.update(balance: balance + 100) }
    t2.sync { row2.update(balance: balance + 100) }

    t1.exec { row2.update(balance: balance - 100) }
    t2.exec { row1.update(balance: balance - 100) }

    t1.commit_transaction
    t2.commit_transaction
  end
ensure
  drop_table? :accounts
end
