RSpec::Matchers.define :have_log_errors do
  match do |runner|
    runner.log.any? { |e| e.is_a? Gana::LogError }
  end
end
