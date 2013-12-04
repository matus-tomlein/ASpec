require 'aquarium'

include Aquarium::Aspects

## ASpec is a simple library that utilizes aspect oriented programming and meta programming
## to enable mocking, method call counting, Liskov Substition Principle testing and more
class ASpec
  attr_reader :return_values,
    :method_call_counts, :expected_method_call_counts,
    :method_call_arguments, :expected_method_call_arguments

  @@class_substitutions = {}

  def initialize
    @replaced_class = ''
    @replacing_classes = [nil]
    @method_mocks = {}
    @aspects = []
    @return_values = []
    @method_call_counts = {}
    @expected_method_call_counts = {}
    @method_call_arguments = {}
    @expected_method_call_arguments = {}
  end

  ## Get the name of the class that should be replacing the original class in LSP testing
  def self.class_substition(original_class)
    return @@class_substitutions[original_class]
  end

  ## Test Liskov Substition Principle
  ## Replaces the replaced_class with each of the replacing_classes during execution
  def lsp(replaced_class, replacing_classes)
    @replaced_class = replaced_class.to_s
    @replacing_classes += if replacing_classes.class == Array
      replacing_classes.map {|item| item.to_s}
    else
      [replacing_classes.to_s]
    end
    self
  end

  ## Replaces the method of the type with the given block
  def mock(type, method, &block)
    type, method = type.to_s, method.to_s
    @method_mocks[[type, method]] = block

    aspect = Aspect.new :around, :calls_to => method, :for_type => eval(type) do |join_point, object, *args|
      key = [object.class.to_s, join_point.method_name.to_s]
      if @method_mocks.has_key? key
        @method_mocks[key].call
      else
        jp.proceed
      end
    end

    @aspects << aspect
    self
  end

  ## Raises exception when the method of the type is called
  def raise_exception(type, method)
    type, method = type.to_s, method.to_s
    aspect = Aspect.new :around, :calls_to => method, :for_type => eval(type) do |join_point, object, *args|
      raise "ASpec doesn't like this at all."
    end

    @aspects << aspect
    self
  end

  ## Defines the expected count of method calls for the method in the type
  def count_method_calls(type, method, expected_count)
    type, method, expected_count = type.to_s, method.to_s, expected_count.to_i
    (@expected_method_call_counts[type] ||= {})[method] = expected_count
    (@method_call_counts[type] ||= {})[method] = 0

    aspect = Aspect.new :around, :calls_to => method, :for_type => eval(type) do |join_point, object, *args|
      @method_call_counts[object.class.to_s][join_point.method_name.to_s] += 1
    end

    @aspects << aspect
    self
  end

  ## Defines the expected method arguments for each of the method calls
  ## expected_arguments is a list of lists of arguments, e.g. [[call1_arg1, call1_arg2], [call2_arg1, call2_arg2]]
  def expect_method_arguments(type, method, expected_arguments)
    type, method = type.to_s, method.to_s
    (@expected_method_call_arguments[type] ||= {})[method] = expected_arguments
    (@method_call_arguments[type] ||= {})[method] = []

    aspect = Aspect.new :around, :calls_to => method, :for_type => eval(type) do |join_point, object, *args|
      (@method_call_arguments[object.class.to_s][join_point.method_name.to_s] ||= []) << args
    end

    @aspects << aspect
    self
  end

  ## Replaces the constructor of the given class with the one from the LSP class subsititutions list
  def self.define_new_method(replaced_class)
    def (eval(replaced_class)).new
      obj = nil
      if ASpec.class_substition(self.to_s).nil?
        the_ancestor = ''
        self.ancestors.each do |ancestor|
          unless ASpec.class_substition(ancestor.to_s).nil?
            the_ancestor = ancestor.to_s
            break
          end
        end
        ASpec.remove_new_method_from_class(the_ancestor)
        obj = self.new
        ASpec.define_new_method(the_ancestor)
      else
        ASpec.remove_new_method_from_class(self.to_s)
        obj = eval(ASpec.class_substition(self.to_s)).new
        ASpec.define_new_method(self.to_s)
      end
      obj
    end
  end

  ## Removes the arbitrary new constructor from the given class
  def self.remove_new_method_from_class(class_name)
    class <<(eval(class_name))
      remove_method :new
    end
  end

  ## Executes the given block
  ## If there are LSP substitutes defined, executes the block for each of them
  def execute
    @replacing_classes.each do |replacing_class|

      unless replacing_class.nil?
        @@class_substitutions[@replaced_class] = replacing_class
        ASpec.define_new_method(@replaced_class)
      end

      @return_values << yield

      ASpec.remove_new_method_from_class(@replaced_class) unless replacing_class.nil?
    end

    @aspects.each do |aspect|
      aspect.unadvise
    end
    @aspects.clear

    self
  end

  ## The first returned value from the execution
  def return_value
    @return_values.first
  end
end
