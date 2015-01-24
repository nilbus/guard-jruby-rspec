require 'spec_helper'

class Guard::JRubyRSpec::Runner::UI; end

describe Guard::JRubyRSpec::Runner do
  subject { described_class.new }

  describe '#run' do

    before(:each) do
      allow(Guard::JRubyRSpec::Runner::UI).to receive(:info)
    end

    it 'keeps the RSpec global configuration between runs' do
      allow(RSpec::Core::Runner).to receive(:run)
      orig_configuration = ::RSpec.configuration
      expect(::RSpec).to receive(:instance_variable_set).with(:@configuration, orig_configuration)

      subject.run(['spec/foo'])
    end

    context 'when passed an empty paths list' do
      it 'returns false' do
        expect(subject.run([])).to be_falsey
      end
    end

    context 'when one of the source files is bad' do
      it 'recovers from syntax errors in files by displaying the error' do
        allow(RSpec::Core::Runner).to receive(:run).and_raise(SyntaxError.new('Bad Karma'))
        expect(Guard::UI).to receive(:error).at_least(1).times
        expect {
          subject.run(['spec/foo'])
        }.to throw_symbol(:task_has_failed)
      end
    end
  end
end
