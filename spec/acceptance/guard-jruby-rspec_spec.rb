describe 'The jruby-rspec guard' do
  around do |example|
    Dir.chdir File.expand_path File.join(__FILE__, '../example') do
      example.run
    end
  end

  let(:run_guard_then_exit) { 'true | bundle exec guard' }

  it 'exits with a successful exit code' do
    expect(system("#{run_guard_then_exit} >/dev/null 2>&1")).to be_truthy
  end

  it 'runs the passing rspec test suite' do
    output = `#{run_guard_then_exit} 2>&1`
    expect(output).to include '0 failures'
  end
end
