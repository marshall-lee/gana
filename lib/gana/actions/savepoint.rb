module Gana::Actions
  class Savepoint < Base
    include Gana::EventedState

    def initialize(db, &block)
      super()
      @db = db
      @block = block
    end

    def run
      if @db.in_transaction?
        tail_action, continuation = @db.transaction(savepoint: true) do
          # SAVEPOINT statement executed
          state!(:succeed)

          catch(:destroy_savepoint, &@block)
        end

        # RELEASE SAVEPOINT or ROLLBACK TO SAVEPOINT executed
        tail_action&.state!(:succeed)

        continuation
      else
        state!(:failed)
        raise 'Savepoint can only be used inside transaction'
      end
    end

    def failed?
      @state == :failed
    end

    def completed?
      @state == :succeed || @state == :failed
    end
  end
end
