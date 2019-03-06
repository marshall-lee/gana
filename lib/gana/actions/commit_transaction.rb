module Gana::Actions
  class CommitTransaction < Base
    include Gana::EventedState

    def initialize(db, continuation)
      super()
      @db = db
      @continuation = continuation
    end

    def run
      if @db.in_transaction?
        throw :end_transaction, [self, @continuation]
      else
        state!(:failed)
        raise "Cannot commit_transaction because it's not started"
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
