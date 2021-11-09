require "rspec/autorun"

module Affable
  DEFAULT_POST_TEXT = "Very lovely indeed!"

  # Trigger a flag, and save a function in case we want to do something
  # special here.
  #
  # But won't this persist? No, because a module would need to
  # be included for this to work. See also the persistence test below
  def extra_affable
    @extra_affable = true
  end

  def method_added(method_name)
    return unless @extra_affable

    @extra_affable = false
    original_method = instance_method(method_name)

    define_method(method_name) do |*args, &fn|
      original_result = original_method.bind(self).call(*args, &fn)
      "#{original_result} Very lovely indeed!"
    end
  end
end

module Affable
  DEFAULT_POST_TEXT = "Very lovely indeed!"

  # Trigger a flag, and save a function in case we want to do something
  # special here. We add the function to demonstrate this can take arguments
  # as well.
  #
  # But won't this persist? No, because a module would need to
  # be included for this to work. See also the persistence test below
  def extra_affable(&fn)
    @extra_affable = true
  end

  def method_added(method_name)
    return unless @extra_affable

    @extra_affable = false
    original_method = instance_method(method_name)


    define_method(method_name) do |*args, &fn|
      original_result = original_method.bind(self).call(*args, &fn)

      "#{original_result} #{DEFAULT_POST_TEXT}"
    end
  end
end

class Lemur
  # We want to `extend`, adding `cache` to our class methods.
  extend Affable

  def initialize(name) @name = name; end

  extra_affable

  def farewell
    "Farewell! It was lovely to chat."
  end

  # Exercise for the reader: How might this work?
  #
  # extra_affable { |original| "#{original} Yes yes quite so."}

  def greeting
    "Why hello there! Isn't it a lovely day?"
  end
end

RSpec.describe "MethodAddedDecoration" do
  describe 'an Affable Lemur' do
    let(:lemur) { Lemur.new("Indigo") }

    it 'has an extra affable farewell' do
      expect(lemur.farewell).to eq(
        "Farewell! It was lovely to chat. Very lovely indeed!"
      )
    end

    # Fix the code above to make this work.
    xit 'has an extra affable greeting' do
      expect(lemur.greeting).to eq(
        "Why hello there! Isn't it a lovely day? Yes yes quite so."
      )
    end
  end

  describe 'State persistence' do
    it 'will not save state in the Affable module' do
      # Setting local variables to be able to extract values
      # out of the class definition here in a moment.
      module_state_before = nil
      class_state_before  = nil
      module_state_after  = nil
      class_state_after   = nil

      Class.new do
        extend Affable

        # Trigger the flag
        extra_affable

        # Once `extra_affable` has been called we expect that the `Affable`
        # module has no state and that the singleton class has the
        # `@extra_affable` instance variable bound to it
        module_state_before = Affable.instance_variable_get(:@extra_affable)
        class_state_before  = instance_variable_get(:@extra_affable)

        # Add a method, which turns the flag back off
        def testing_method; end

        # After the method is added we expect the flag to be negated, and
        # that the `Affable` module still contains no state.
        module_state_after = Affable.instance_variable_get(:@extra_affable)
        class_state_after  = instance_variable_get(:@extra_affable)
      end

      # Afterwards we confirm our assumptions above using the local variables
      # we set before the class definition, and assigned inside of it.
      expect(module_state_before).to eq(nil)
      expect(class_state_before).to eq(true)

      expect(module_state_after).to eq(nil)
      expect(class_state_after).to eq(false)
    end
  end
end
