desc 'Generate parser with racc'
task :racc do
	print `racc -oparser.rb parse.y`
end

desc 'Run integration test'
task :itest => :racc do
  print `ruby test/integration_tests.rb`
end


