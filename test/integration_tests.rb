require 'pathname'
require 'colorized_string'
require 'diffy'

test_root = File.join(File.dirname(__FILE__), 'lang')
@interp_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'wtf.rb'))
@io = STDOUT

def traverse(current_dir)
  n = 0
  @io.puts("Entering #{current_dir}:")
  Dir.entries(current_dir).each do |file|
    file_path = File.join(current_dir, file)
    if File.directory?(file_path) && !%w(. ..).include?(file)
      traverse(file_path)
    elsif File.file?(file_path)
      if file =~ /\.wtf\z/
        # get parameter
        params = ''
        open(file_path) do |f|
          first_line = f.readline
          if first_line =~ /^#@(.*)$/
            params = $1
          end
        end
        txt_file_path = File.join(current_dir, Pathname.new(file).basename('.wtf').to_s + '.txt')
        if File.exist?(txt_file_path)
          test_start_time = Time.now
          output = `ruby #{@interp_path} --file #{file_path} -a #{params}`
          expected = File.read(txt_file_path)
          unless output == expected
            diff = Diffy::Diff.new(output, expected).to_s
            raise "integration test failed!\n" +
                      "file: '#{file_path}'\n" +
                      "output: \n#{output}\n------\n" +
                      "expected: \n#{expected}\n------\n" +
                      "diff: \n#{diff}\n------\n"
          end
          test_delta_time = Time.now - test_start_time
          @io.puts('  %-4d%-30s%s  %0.3fs' % [n, file_path, ColorizedString['[Passed]'].colorize(:green), test_delta_time])
          n += 1
        else
          raise "file not found #{txt_file_path}"
        end
      end
    end
  end
end

traverse(test_root)
