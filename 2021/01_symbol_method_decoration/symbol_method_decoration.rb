require "rspec/autorun"

module SymbolCacheDecoration
  def cache(method_name)
    # The original method we want to overwrite is an instance method.
    #
    # Since this is `extend`ed below, we're in the context of the class,
    # not the instance, so we need to ask for the instance method
    # explicitly.
    #
    # Do note this is an UnboundMethod ( https://ruby-doc.org/core-3.0.2/UnboundMethod.html ),
    # meaning we have to bind it back to an instance of the class for
    # it to work, which you'll see below.
    original_method = instance_method(method_name)

    # `define_method` defines instance methods, versus `define_singleton_method`
    # which would define class (or singleton methods).
    define_method(method_name) do |*args, &fn|
      # The instance variable we use here can be named after the class
      # it caches.
      ivar = "@#{method_name}".to_sym

      # If the variable is defined, the cache has been set, return
      # the value. Why not just use `instance_variable_get`? If the cached
      # method legitimately returns `false` or `nil` we want to preserve
      # that, rather than rerunning the uncached version.
      if instance_variable_defined?(ivar)
        return instance_variable_get(ivar)
      end

      # If there's no cache set, we want to call the original method. Since
      # the original method is an UnboundMethod we need to `bind` it back
      # to `self`, which is our current instance of the class.
      #
      # Binding it to `self` gives it the context it needs to run, and
      # returns a `method` we can call.
      value = original_method.bind(self).call(*args, &fn)

      # Once we have that we can set the cache. `instance_variable_set` also
      # returns the value, so this works as an implicit return
      instance_variable_set(ivar, value)
    end
  end
end

# Uncommented so you can see it more clearly. Technically this overwrites the
# above, but it's the same code, and not that expensive to do.
module SymbolCacheDecoration
  def cache(method_name)
    original_method = instance_method(method_name)

    define_method(method_name) do |*args, &fn|
      ivar = "@#{method_name}".to_sym

      return instance_variable_get(ivar) if instance_variable_defined?(ivar)

      value = original_method.bind(self).call(*args, &fn)
      instance_variable_set(ivar, value)
    end
  end
end

class Lemur
  # We want to `extend`, adding `cache` to our class methods.
  extend SymbolCacheDecoration

  # This allows us to call `cache` in the Lemur class directly like so:
  cache def expensive_method
    (1..1_000_000).to_a.sample(10)
  end
end

# A quick method to check how long something took, returning the
# value as well as the time it took to run.
def timed_value(&fn)
  start_time = Time.now
  [fn.call, Time.now - start_time]
end

RSpec.describe "SymbolCacheDecoration" do
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
