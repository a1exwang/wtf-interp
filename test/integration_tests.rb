require 'pathname'
require 'colorized_string'
require 'diffy'

case_dir = File.join(File.dirname(__FILE__), 'lang')
interp_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'wtf.rb'))

n = 0
Dir.entries(case_dir).each do |file|
  if file =~ /\.wtf\z/
    wtf_file_path = File.join(case_dir, file)

    # get parameter
    params = ''
    open(wtf_file_path) do |f|
      first_line = f.readline
      if first_line =~ /^#@(.*)$/
        params = $1
      end
    end
    txt_file_path = File.join(case_dir, Pathname.new(file).basename('.wtf').to_s + '.txt')
    if File.exist?(txt_file_path)
      output = `ruby #{interp_path} --file #{wtf_file_path} -a #{params}`
      expected = File.read(txt_file_path)
      unless output == expected
        diff = Diffy::Diff.new(output, expected).to_s
        raise "integration test failed!\n" +
            "file: '#{wtf_file_path}'\n" +
            "output: \n#{output}\n------\n" +
            "expected: \n#{expected}\n------\n" +
            "diff: \n#{diff}\n------\n"
      end

      puts('%-8d%-30s%s' % [n, wtf_file_path, ColorizedString['[Passed]'].colorize(:green)])
      n += 1
    else
      raise "file not found #{txt_file_path}"
    end
  end
end