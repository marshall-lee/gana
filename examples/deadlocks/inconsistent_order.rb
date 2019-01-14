gana do |t1, t2|
  table = new_table :lol do
    primary_key :id
  end

  print "Generating data..."

  5_000.times { table.insert }

  t1.begin_transaction
  t2.begin_transaction

  t1.exec do
    table.for_update.select_map(1)
  end

  t2.exec do
    table.reverse(:id).for_update.select_map(1)
  end

  t2.commit_transaction
  t1.commit_transaction
end
