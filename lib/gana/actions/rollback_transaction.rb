module Gana::Actions
  class RollbackTransaction < Base
    include Gana::EventedState

    def initialize(db, continuation)
      super()
      @db = db
      @continuation = continuation
    end

    def run
      if @db.in_transaction?
        @db.rollback_on_exit
        throw :end_transaction, [self, @continuation]
      else
        state!(:failed)
        raise "Cannot rollback_transaction because it's not started"
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
