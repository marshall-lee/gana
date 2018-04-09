gana do |t1, t2, t3|
  t1.sync { execute 'SELECT pg_sleep(1)' }
  t2.sync { execute 'SELECT pg_sleep(1)' }
  t3.sync { execute 'SELECT pg_sleep(1)' }
  t1.exec { execute 'SELECT pg_sleep(3)' }
  t2.exec { execute 'SELECT pg_sleep(2)' }
  t3.exec { execute 'SELECT pg_sleep(1)' }
end
