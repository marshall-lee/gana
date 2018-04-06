gana do |t|
  t.begin_transaction
  t.exec { raise ':(' }
  t.commit_transaction
end
