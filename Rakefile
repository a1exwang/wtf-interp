desc 'racc'
task :racc do
	print `racc -oparser.rb parse.y`
end

desc 'run interp'
task run: :racc do
  load 'wtf.rb'
end

desc 'run file'
task run_file: :racc do
  puts `ruby wtf.rb wtfs/a.wtf`
end

task :default => :run_file
