require 'spec_helper'
require 'guard/jruby-rspec/containment'

class Guard::JRubyRSpec
  describe Containment do
    subject(:containment) { described_class.new }

    describe '#protect' do
      it 'runs the block that is passed to it' do
        expect { |block| containment.protect &block }.to yield_control
      end

      it 'uses a default error_handler' do
        expect(Guard::UI).to receive(:error).at_least(1).times
        expect { containment.protect { raise 'busted' } }.to throw_symbol(:task_has_failed)
      end

      context 'with a custom error_handler' do
        subject(:containment) { described_class.new(:error_handler => lambda { |error| @custom_handler_called = true }) }

        it 'calls the custom error_handler' do
          expect(Guard::UI).to receive(:error).never
          expect { containment.protect { raise 'busted' } }.to throw_symbol(:task_has_failed)
          expect(@custom_handler_called).to be_truthy
        end
      end
    end
  end
end
