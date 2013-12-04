require_relative 'aspec'

class AppleTest
  def apple
    "apples"
  end

  def argo(arg1, arg2, arg3)
    "nice"
  end
end

class OrangeTest < AppleTest
  def apple
    "oranges"
  end
end

class BananaTest < AppleTest
  def apple
    "bananas"
  end
end

describe ASpec do
  it "should test LSP for all given classes" do
    ASpec.new.lsp(:AppleTest, [:BananaTest, :OrangeTest]).execute do
      test = AppleTest.new
      test.apple
    end.return_values.should == ['apples', 'bananas', 'oranges']
  end

  it "should mock methods correctly" do
    ASpec.new.mock(:AppleTest, :apple) { 'pineapples' }.execute { AppleTest.new.apple }.return_value.should == 'pineapples'
    AppleTest.new.apple.should == 'apples'
  end

  it "should mock multiple methods" do
    aspec = ASpec.new
    aspec.mock(:AppleTest, :apple) { 'pineapples' }
    aspec.mock(:OrangeTest, :apple) { 'pears' }
    aspec.execute { [AppleTest.new.apple, OrangeTest.new.apple] }
    aspec.return_value.first.should == 'pineapples'
    aspec.return_value.last.should == 'pears'
    AppleTest.new.apple.should == 'apples'
    OrangeTest.new.apple.should == 'oranges'
  end

  it "should raise exceptions correctly" do
    ASpec.new.raise_exception(:AppleTest, :apple).execute do
      exception = false
      begin
        AppleTest.new.apple
      rescue
        exception = true
      end
      exception
    end.return_value.should == true

    AppleTest.new.apple.should == 'apples'
  end

  it "should raise multiple exceptions" do
    aspec = ASpec.new
    aspec.raise_exception :AppleTest, :apple
    aspec.raise_exception :OrangeTest, :apple
    aspec.execute do
      exception = false
      begin
        AppleTest.new.apple
      rescue
        begin
          OrangeTest.new.apple
        rescue
          exception = true
        end
      end
      exception
    end.return_value.should == true

    AppleTest.new.apple.should == 'apples'
  end

  it "should count method calls" do
    aspec = ASpec.new
    aspec.count_method_calls :AppleTest, :apple, 2
    aspec.count_method_calls :AppleTest, :argo, 1
    aspec.count_method_calls :OrangeTest, :apple, 1
    aspec.count_method_calls :BananaTest, :apple, 0
    aspec.execute do
      apple = AppleTest.new
      apple.apple
      apple.apple
      apple.argo 'a1','a2','a3'
      OrangeTest.new.apple
    end
    aspec.method_call_counts.should == aspec.expected_method_call_counts

    aspec = ASpec.new
    aspec.count_method_calls :AppleTest, :apple, 1
    aspec.count_method_calls :BananaTest, :apple, 0
    aspec.execute do
      AppleTest.new.apple
      AppleTest.new.apple
    end
    (aspec.method_call_counts == aspec.expected_method_call_counts).should == false
  end

  it "should keep track of method arguments" do
    aspec = ASpec.new
    aspec.expect_method_arguments :AppleTest, :argo, [['a1', 'a2', 'a3'], ['a2', 'a1', 'a0']]
    aspec.expect_method_arguments :AppleTest, :apple, [[]]
    aspec.execute do
      apple = AppleTest.new
      apple.apple
      apple.argo 'a1', 'a2', 'a3'
      apple.argo 'a2', 'a1', 'a0'
    end
    aspec.method_call_arguments.should == aspec.expected_method_call_arguments

    aspec = ASpec.new
    aspec.expect_method_arguments :AppleTest, :argo, [['a1', 'a2', 'a3'], ['a2', 'a1', 'a1']]
    aspec.expect_method_arguments :AppleTest, :apple, [[1]]
    aspec.execute do
      apple = AppleTest.new
      apple.apple
      apple.argo 'a1', 'a2', 'a3'
      apple.argo 'a2', 'a1', 'a0'
    end
    (aspec.method_call_arguments == aspec.expected_method_call_arguments).should == false
  end
end
