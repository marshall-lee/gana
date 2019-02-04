module DatabaseHelper
  def postgres
    @postgres ||= Sequel.connect(adapter: :postgres, database: 'gana_test', max_connections: 10)
  end

  alias db postgres
end
