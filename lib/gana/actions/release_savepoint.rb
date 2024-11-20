module Gana::Actions
  class ReleaseSavepoint < Base
    include Gana::EventedState

    def initialize(db, continuation)
      super()
      @db = db
      @continuation = continuation
    end

    def run
      if @db.in_transaction?
        throw :destroy_savepoint, [self, @continuation]
      else
        state!(:failed)
        raise "Cannot release_savepoint because it's not started"
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
