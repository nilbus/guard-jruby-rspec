describe 'The jruby-rspec guard' do
  around do |example|
    Dir.chdir File.expand_path File.join(__FILE__, '../example') do
      example.run
    end
  end

  let(:run_guard_then_exit) { 'true | bundle exec guard' }

  it 'runs the passing rspec test suite' do
    output = `#{run_guard_then_exit} 2>&1`
    expect(output).to include '0 failures'
  end
end
