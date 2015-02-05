describe 'success' do
  it 'looks so green' do
    puts 'ran a spec'
    expect('guard-jruby-rspec is running!').not_to be_nil
  end
end
