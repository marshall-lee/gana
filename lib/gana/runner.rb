module Gana
  class Runner
    def initialize(db, printer_class: nil, threads: nil, &block)
      @db = db
      unless block
        raise ArgumentError, 'You must pass  block'
      end
      threads ||= block.arity
      unless threads > 0
        raise ArgumentError,
              'Cannot determine threads number from the block arity'
      end
      @log = []
      @workers = Array.new(threads) { |i| Worker.new(self, i) }
      printer_class ||= Gana.default_printer_class
      printer = printer_class.new(self) if printer_class
      @db.server_version
      context = ExecutionContext.new(self)
      context.instance_exec(*@workers, &block)
      @workers.each(&:terminate)
      printer.finalize if printer
    end

    attr_reader :db, :workers, :log
  end
end
