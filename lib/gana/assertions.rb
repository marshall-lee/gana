require 'minitest'

module Gana
  class Assertions
    include Minitest::Assertions

    def initialize
      @assertions = 0
    end

    attr_accessor :assertions

    ALL = Minitest::Assertions.instance_methods.grep(/^(assert|refute)/)
  end
end
