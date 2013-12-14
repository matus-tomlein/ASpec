require_relative 'aspec'

class Car
  def manufacturer
    'any'
  end
end

class BMW < Car
  def manufacturer
    'BMW'
  end
end

class Mercedes < Car
  def manufacturer
    'Mercedes'
  end
end

class Skoda < Car
  def manufacturer
    'Skoda'
  end

  def price(type, currency)
    ## Missing implementation
    10000
  end
end

describe ASpec do
  it "should test LSP for all given classes" do
    ASpec.new.lsp(:Car, [:BMW, :Mercedes, :Skoda]).execute do
      car = Car.new
      car.manufacturer
    end.return_values.should == ['any', 'BMW', 'Mercedes', 'Skoda']
  end

  it "should stub methods correctly" do
    ASpec.new.stub(:BMW, :manufacturer) { 'Dacia' }.execute { BMW.new.manufacturer }.return_value.should == 'Dacia'
    BMW.new.manufacturer.should == 'BMW'
  end

  it "should stub multiple methods" do
    aspec = ASpec.new
    aspec.stub(:BMW, :manufacturer) { 'Dacia' }
    aspec.stub(:Skoda, :manufacturer) { 'Bentley' }
    aspec.execute { [BMW.new.manufacturer, Skoda.new.manufacturer] }
    aspec.return_value.first.should == 'Dacia'
    aspec.return_value.last.should == 'Bentley'
    BMW.new.manufacturer.should == 'BMW'
    Skoda.new.manufacturer.should == 'Skoda'
  end

  it "should raise exceptions correctly" do
    ASpec.new.raise_exception(:Mercedes, :manufacturer).execute do
      exception = false
      begin
        Mercedes.new.manufacturer
      rescue
        exception = true
      end
      exception
    end.return_value.should == true

    Mercedes.new.manufacturer.should == 'Mercedes'
  end

  it "should raise multiple exceptions" do
    aspec = ASpec.new
    aspec.raise_exception :Mercedes, :manufacturer
    aspec.raise_exception :BMW, :manufacturer
    aspec.execute do
      exception = false
      begin
        Mercedes.new.manufacturer
      rescue
        begin
          BMW.new.manufacturer
        rescue
          exception = true
        end
      end
      exception
    end.return_value.should == true

    Mercedes.new.manufacturer.should == 'Mercedes'
    BMW.new.manufacturer.should == 'BMW'
  end

  it "should count method calls" do
    aspec = ASpec.new
    aspec.count_method_calls :Skoda, :manufacturer, 2
    aspec.count_method_calls :Skoda, :price, 1
    aspec.count_method_calls :Mercedes, :manufacturer, 1
    aspec.count_method_calls :BMW, :manufacturer, 0
    aspec.execute do
      skoda = Skoda.new
      skoda.manufacturer
      skoda.manufacturer
      skoda.price 'Octavia', 'EUR'
      Mercedes.new.manufacturer
    end
    aspec.method_call_counts.should == aspec.expected_method_call_counts

    aspec = ASpec.new
    aspec.count_method_calls :BMW, :manufacturer, 1
    aspec.count_method_calls :Mercedes, :manufacturer, 0
    aspec.execute do
      BMW.new.manufacturer
      BMW.new.manufacturer
    end
    (aspec.method_call_counts == aspec.expected_method_call_counts).should == false
  end

  it "should keep track of method arguments" do
    aspec = ASpec.new
    aspec.expect_method_arguments :Skoda, :price, [['Octavia', 'EUR'], ['Rapid', 'EUR']]
    aspec.expect_method_arguments :Skoda, :manufacturer, [[]]
    aspec.execute do
      skoda = Skoda.new
      skoda.manufacturer
      skoda.price 'Octavia', 'EUR'
      skoda.price 'Rapid', 'EUR'
    end
    aspec.method_call_arguments.should == aspec.expected_method_call_arguments

    aspec = ASpec.new
    aspec.expect_method_arguments :Skoda, :price, [['Octavia', 'EUR'], ['Rapid', 'EUR']]
    aspec.expect_method_arguments :Skoda, :manufacturer, [[1]]
    aspec.execute do
      skoda = Skoda.new
      skoda.manufacturer
      skoda.price 'Octavia', 'EUR'
      skoda.price 'Rapid', 'EUR'
    end
    (aspec.method_call_arguments == aspec.expected_method_call_arguments).should == false
  end
end
