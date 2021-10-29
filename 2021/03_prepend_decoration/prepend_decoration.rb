require "rspec/autorun"

module Timeable
  CONST_NAME = "Timing"

  # Why use `extend` when we're prepending? Because `measure` is a
  # class method we'll need to add methods to be timed later
  def self.extended(klass)
    # Create a new module to add timing methods to
    timing_module = Module.new

    # Prepend that module to the class which extended this
    klass.prepend(timing_module)
    klass.const_set(CONST_NAME, timing_module)
  end

  def measure(method_name)
    # In the context of the `Timing` module we want to define a method. Why
    # there? Because the `timing_module` is prepended to the class that
    # extends this.
    #
    # Also `class_eval` and `module_eval` are the same thing.
    self.const_get(CONST_NAME).module_eval do
      define_method(method_name) do |*args, &fn|
        start_time = Time.now
        result = super(*args, &fn)
        puts "Time taken: #{Time.now - start_time}"
        result
      end
    end
  end
end

class Lemur
  extend Timeable

  measure def expensive_method
    @expensive_method ||= (1..1_000_000).to_a.sample(10)
  end
end

# A quick method to check how long something took, returning the
# value as well as the time it took to run.
def timed_value(&fn)
  start_time = Time.now
  [fn.call, Time.now - start_time]
end

RSpec.describe "PrependDecoration" do
  describe 'Timing' do
    it 'caches expensive methods' do
      lemur = Lemur.new

      # Get the first value and how long it took to get it
      value, first_time_taken = timed_value { lemur.expensive_method }

      # Three times to get a few deltas to compare against.
      3.times do
        # Get the (hopefully) cached value, and how long it took to get it
        cached_value, new_time_taken = timed_value { lemur.expensive_method }

        # Value should remain the same as the cached value
        expect(value).to eq(cached_value)

        # Expected to be around two orders of magnitude faster. In truth it's
        # more around 100x faster, but this gives us a reasonable delta to
        # test against
        expect(new_time_taken).to be < (first_time_taken / 10)
      end
    end
  end

  describe 'State persistence' do
    it 'will not save state in the Affable module' do
      # Local variables for capturing state inside the class
      # definition below
      timing_methods_before = nil
      timing_methods_after  = nil
      testing_owner_before  = nil
      testing_owner_after   = nil

      # This time we want to work with the class, so we capture it in a
      # variable
      anonymous_class = Class.new do
        extend Timeable

        # We start by defining the initial method, without the Symbol Method
        # decoration so we can capture some state around that method.
        def testing; end

        # We want to see that there are no instance methods on the prepended
        # timing module, and that the `testing` method currently resolves to
        # the anonymous class.
        timing_methods_before = self::Timing.instance_methods
        testing_owner_before  = new.method(:testing).owner

        # Normally we'd do `measure def testing`, but again, we wanted to capture
        # some state around that operation, hence the more explicit Symbol call
        # here
        measure :testing

        # After the prepending method is called we want to see if the new method
        # was added to the timing module, and if the class considers the
        # `testing` method to be under the timing module, indicating successful
        # prepending.
        timing_methods_after = self::Timing.instance_methods
        testing_owner_after  = new.method(:testing).owner
      end

      # Our expectation here is that before the `measure` method is called
      # there won't be any methods on the timing module, and after we'll
      # see the `testing` method there.
      expect(timing_methods_before).to eq([])
      expect(timing_methods_after).to eq([:testing])

      # Along with this we expect that the `testing` method will initially
      # resolve to the anonymous class before `measure` is called, and
      # will resolve to the timing module after.
      expect(testing_owner_before).to eq(anonymous_class)
      expect(testing_owner_after).to eq(anonymous_class.const_get("Timing"))
    end
  end
end
