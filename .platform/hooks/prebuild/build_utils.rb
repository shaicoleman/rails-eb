#!/opt/elasticbeanstalk/lib/ruby/bin/ruby
# frozen_string_literal: true

require 'erb'
require 'open3'
require 'fileutils'
require 'json'

def copy_file(file)
  source = "#{__dir__}/files/#{file[:source]}"
  if file[:template] == 'erb'
    contents = ERB.new(File.read(source)).result
    File.write('/tmp/erb', contents)
    source = '/tmp/erb'
  end
  target = file[:target]
  bak_file = "#{target}.old"
  if File.exist?(target)
    return if FileUtils.compare_file(source, target)
    FileUtils.cp(target, bak_file) unless file[:no_backup] || File.exist?(bak_file)
  end

  FileUtils.mkdir_p(File.dirname(target))
  FileUtils.cp(source, target)
  add_handler(file[:handler])
  FileUtils.rm_f('/tmp/erb') if File.exist?('/tmp/erb')
  log("Copy: #{file[:source]} to #{file[:target]}")
end

def copy_files
  FILES.each do |file|
    copy_file(file)
  end
end

def create_symlinks
  SYMLINKS.each do |symlink|
    next if File.symlink?(symlink[:target]) && File.realpath(symlink[:source]) == File.realpath(symlink[:target])

    FileUtils.ln_sf(symlink[:source], symlink[:target])
    log("Symlink: #{symlink[:source]} to #{symlink[:target]}")
  end
end

def add_handler(handler)
  return unless handler

  @handlers << handler unless @handlers.include?(handler)
end

def run_handlers
  @handlers.each do |handler|
    send(handler)
  end
end


def run(cmd, ignore_errors: false)
  log("Run: #{cmd.squish}")
  stdout_str, stderr_str, status = Open3.capture3(cmd)
  unless status.success?
    message = "Error running: #{cmd.squish}\nOutput: #{stdout_str.squish}, Errors: #{stderr_str.squish}"
    error(message, ignore_errors: ignore_errors)
  end
  { stdout: stdout_str, stderr: stderr_str, status: status }
end

def log(message)
  puts message
  File.open('/var/log/deploy.log', 'a') { |f| f.print "#{Time.now.utc} #{message}\n" }
end

def error(message, ignore_errors: false)
  log(message)
  abort(message) unless ignore_errors
end

def init
  abort 'Must be root' unless Process.uid == 0
  Dir.chdir("#{__dir__}/../../..")  
  @handlers = []
  @script_name = File.basename($PROGRAM_NAME, '.rb')
  log("#{@script_name} start")
end

def finish
  log("#{@script_name} success")
end

class String
  def squish
    dup.gsub(/[[:space:]]+/, ' ').strip
  end
end
