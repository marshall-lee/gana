module Gana
  require 'gana/version'
  require 'gana/runner'
  require 'gana/worker'
  require 'gana/actions'
  require 'gana/statement'
  require 'gana/log_error'

  class << self
    attr_accessor :default_printer_class
  end
end
