module Gana::Actions
  class BeginTransaction < Base
    include Gana::EventedState

    def initialize(db, **options, &block)
      super()
      @db = db
      @options = options
      @block = block
    end

    def run
      if @db.in_transaction?
        state!(:failed)
        raise 'Transaction is already started'
      else
        end_action, continuation = @db.transaction(@options) do
          # BEGIN statement executed
          state!(:succeed)

          catch(:end_transaction, &@block)
        end

        # COMMIT or ROLLBACK executed
        end_action.state!(:succeed) if end_action

        continuation
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
