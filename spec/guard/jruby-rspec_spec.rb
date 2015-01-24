require 'spec_helper'

describe Guard::JRubyRSpec do
  let(:default_options) do
    {
      :focus_on_failed => false,
      :all_after_pass => true,
      :all_on_start => true,
      :keep_failed => true,
      :spec_paths => ['spec'],
      :spec_file_suffix => "_spec.rb",
      :run_all => {},
      :monitor_file => ".guard-jruby-rspec",
      :custom_reloaders => []
    }
  end

  let(:custom_watchers) do
    [Guard::Watcher.new(%r{^spec/(.+)$}, lambda { |m| "spec/#{m[1]}_match"})]
  end

  subject { described_class.new custom_watchers, default_options}

  let(:inspector) { double(described_class::Inspector, :excluded= => nil, :spec_paths= => nil, :spec_paths => [], :clean => []) }
  let(:runner)    { double(described_class::Runner, :set_rspec_version => nil, :rspec_version => nil) }

  before do
    described_class::Runner.stub(:new => runner)
    described_class::Inspector.stub(:new => inspector)
    allow(Guard::UI).to receive(:info)
  end

  shared_examples_for 'clear failed paths' do
    it 'should clear the previously failed paths' do
      allow(inspector).to receive(:clean).and_return(['spec/foo_match'], ['spec/bar_match'])

      expect(runner).to receive(:run).with(['spec/foo_match']) { false }
      expect { subject.run_on_change(['spec/foo']) }.to throw_symbol :task_has_failed

      expect(runner).to receive(:run) { true }
      expect { subject.run_all }.to_not throw_symbol # this actually clears the failed paths

      expect(runner).to receive(:run).with(['spec/bar_match']) { true }
      subject.run_on_change(['spec/bar'])
    end
  end

  describe '.initialize' do
    it 'creates an inspector' do
      expect(described_class::Inspector).to receive(:new).with(default_options.merge(:foo => :bar))

      described_class.new([], :foo => :bar)
    end

    it 'creates a runner' do
      expect(described_class::Runner).to receive(:new).with(default_options.merge(:foo => :bar))

      described_class.new([], :foo => :bar)
    end
  end

  describe '#start' do
    it 'calls #run_all' do
      expect(subject).to receive(:run_all)
      subject.start
    end

    context ':all_on_start option is false' do
      let(:subject) { subject = described_class.new([], :all_on_start => false) }

      it "doesn't call #run_all" do
        expect(subject).not_to receive(:run_all)
        subject.start
      end
    end
  end

  describe '#run_all' do
    before { inspector.stub(:spec_paths => ['spec']) }

    it "runs all specs specified by the default 'spec_paths' option" do
      inspector.stub(:spec_paths => ['spec', 'spec/fixtures/other_spec_path'])
      expect(runner).to receive(:run).with(['spec', 'spec/fixtures/other_spec_path'], anything) { true }

      subject.run_all
    end

    it 'passes the :run_all options' do
      subject = described_class.new([], {
        :rvm => ['1.8.7', '1.9.2'], :cli => '--color', :run_all => { :cli => '--format progress' }
      })
      expect(runner).to receive(:run).with(['spec'], hash_including(:cli => '--format progress')) { true }

      subject.run_all
    end

    it 'passes the message to the runner' do
      expect(runner).to receive(:run).with(['spec'], hash_including(:message => 'Running all specs')) { true }

      subject.run_all
    end

    it "throws task_has_failed if specs don't passed" do
      expect(runner).to receive(:run) { false }

      expect { subject.run_all }.to throw_symbol :task_has_failed
    end

    it_should_behave_like 'clear failed paths'
  end

  describe '#reload_rails' do
    it 'continues silently if the supported Rails 3.2+ version of Rails reloading is not supported' do
      expect(defined?(::ActionDispatch::Reloader)).to be_falsey
      expect {
        subject.reload_rails
      }.not_to raise_exception
    end

    it "reloads Rails if it's loaded" do
      stub_const '::ActionDispatch::Reloader', double
			expect(ActionDispatch::Reloader).to receive 'cleanup!'
			expect(ActionDispatch::Reloader).to receive 'prepare!'
			subject.reload_rails
    end
  end

  describe '#reload_factory_girl' do
    it 'continues silently if FactoryGirl is not loaded' do
      expect(defined?(::FactoryGirl)).to be_falsey
      expect {
        subject.reload_factory_girl
      }.not_to raise_exception
    end

    it "reloads FactoryGirl if it's loaded" do
      stub_const 'FactoryGirl', double
			expect(FactoryGirl).to receive 'reload'
			subject.reload_factory_girl
    end
  end

  describe '#reload_paths' do
    it 'should reload files other than spec files' do
      lib_file = 'lib/myapp/greeter.rb'
      spec_file = 'specs/myapp/greeter_spec.rb'
      allow(File).to receive(:exists?).and_return(true)
      allow(subject).to receive(:load)
      expect(subject).to receive(:load).with(lib_file)
      expect(subject).not_to receive(:load).with(spec_file)

      subject.reload_paths([lib_file, spec_file])
    end

    it 'should use @options to alter spec file suffix' do
      subject = described_class.new([], :spec_file_suffix => '_test.rb')
      test_file = 'specs/myapp/greeter_test.rb'
      allow(File).to receive(:exists?).and_return(true)
      allow(subject).to receive(:load)
      expect(subject).not_to receive(:load).with(test_file)

      subject.reload_paths([test_file])
    end

    it 'recovers from exceptions raised when loading files' do
      lib_file = 'lib/myapp/greeter.rb'
      allow(File).to receive(:exists?).and_return(true)
      allow(subject).to receive(:load).and_raise("This fires and deactivates the jruby-rspec guard")
      allow(Guard::UI).to receive(:error)
      expect {
        subject.reload_paths([lib_file])
      }.to throw_symbol(:task_has_failed)
    end
  end

  describe '#run_on_change' do
    before { inspector.stub(:clean => ['spec/foo_match']) }

    it 'runs rspec with paths' do
      expect(runner).to receive(:run).with(['spec/foo_match']) { true }

      subject.run_on_change(['spec/foo'])
    end

    context 'the changed specs pass after failing' do
      it 'calls #run_all' do
        expect(runner).to receive(:run).with(['spec/foo_match']) { false }

        expect { subject.run_on_change(['spec/foo']) }.to throw_symbol :task_has_failed

        expect(runner).to receive(:run).with(['spec/foo_match']) { true }
        expect(subject).to receive(:run_all)

        expect { subject.run_on_change(['spec/foo']) }.to_not throw_symbol
      end

      context ':all_after_pass option is false' do
        subject { described_class.new(custom_watchers, :all_after_pass => false) }

        it "doesn't call #run_all" do
          expect(runner).to receive(:run).with(['spec/foo_match']) { false }

          expect { subject.run_on_change(['spec/foo']) }.to throw_symbol :task_has_failed

          expect(runner).to receive(:run).with(['spec/foo_match']) { true }
          expect(subject).not_to receive(:run_all)

          expect { subject.run_on_change(['spec/foo']) }.to_not throw_symbol
        end
      end
    end

    context 'the changed specs pass without failing' do
      it "doesn't call #run_all" do
        expect(runner).to receive(:run).with(['spec/foo_match']) { true }

        expect(subject).not_to receive(:run_all)

        subject.run_on_change(['spec/foo'])
      end
    end

    it 'keeps failed spec and rerun them later' do
      subject = described_class.new(custom_watchers, :all_after_pass => false)

      expect(inspector).to receive(:clean).with(['spec/bar_match']).and_return(['spec/bar_match'])
      expect(runner).to receive(:run).with(['spec/bar_match']) { false }

      expect { subject.run_on_change(['spec/bar']) }.to throw_symbol :task_has_failed

      expect(inspector).to receive(:clean).with(['spec/foo_match', 'spec/bar_match']).and_return(['spec/foo_match', 'spec/bar_match'])
      expect(runner).to receive(:run).with(['spec/foo_match', 'spec/bar_match']) { true }

      subject.run_on_change(['spec/foo'])

      expect(inspector).to receive(:clean).with(['spec/foo_match']).and_return(['spec/foo_match'])
      expect(runner).to receive(:run).with(['spec/foo_match']) { true }

      subject.run_on_change(['spec/foo'])
    end

    it "throws task_has_failed if specs doesn't pass" do
      expect(runner).to receive(:run).with(['spec/foo_match']) { false }

      expect { subject.run_on_change(['spec/foo']) }.to throw_symbol :task_has_failed
    end

    it "works with watchers that have an array of test targets" do
      subject = described_class.new([Guard::Watcher.new(%r{^spec/(.+)$}, lambda { |m| ["spec/#{m[1]}_match", "spec/#{m[1]}_another.rb"]})])

      test_targets = ["spec/quack_spec_match", "spec/quack_spec_another.rb"]

      expect(inspector).to receive(:clean).with(test_targets).and_return(test_targets)
      expect(runner).to receive(:run).with(test_targets) { true }
      subject.run_on_change(['spec/quack_spec'])

    end


    it "works with watchers that don't have an action" do
      subject = described_class.new([Guard::Watcher.new(%r{^spec/(.+)$})])

      expect(inspector).to receive(:clean).with(anything).and_return(['spec/quack_spec'])
      expect(runner).to receive(:run).with(['spec/quack_spec']) { true }

      subject.run_on_change(['spec/quack_spec'])
    end

    it "works with watchers that do have an action" do
      watcher_with_action = double(Guard::Watcher, :match => :matches, :action => true)
      expect(watcher_with_action).to receive(:call_action).with(:matches).and_return('spec/foo_match')

      subject = described_class.new([watcher_with_action])

      expect(inspector).to receive(:clean).with(['spec/foo_match']).and_return(['spec/foo_match'])
      expect(runner).to receive(:run).with(['spec/foo_match']) { true }

      subject.run_on_change(['spec/foo'])
    end
  end
end

