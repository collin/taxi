abort "Use Ruby 1.9 to build Taxi" unless RUBY_VERSION["1.9"]

require 'rake-pipeline'
require './version'
require 'github_uploader'
require 'colored'

def build
  Rake::Pipeline::Project.new("Assetfile")
end

def err(*args)
  STDERR.puts(*args)
end

desc "Strip trailing whitespace for CoffeeScript files in packages"
task :strip_whitespace do
  Dir["{src,test}/**/*.coffee"].each do |name|
    body = File.read(name)
    File.open(name, "w") do |file|
      file.write body.gsub(/ +\n/, "\n")
    end
  end
end

desc "Compile CoffeeScript"
task :coffeescript => :clean do
  puts "Compiling CoffeeScript"
  `coffee -co lib/ src/`
  puts "Done"
end


desc "Build Taxi"
task :dist => [:coffeescript, :strip_whitespace] do
  puts "Building Taxi..."
  build.invoke
  puts "Done"
end

desc "Clean build artifacts from previous builds"
task :clean do
  puts "Cleaning build..."
  `rm -rf ./lib/*`
  build.clean
  puts "Done"
end


desc "Install development dependencies with hip"
task :vendor => :dist do
  system "hip install --file=dist/taxi.html --out=./vendor --dev"
end

def exec_test
  cmd = %|phantomjs ./test/qunit/run-qunit.js "file://localhost#{File.dirname(__FILE__)}/test/index.html"|

  # Run the tests
  err "Running tests"
  err cmd
  success = system(cmd)  
end

task :exec_test do
  exec_test
end

desc "Run tests with phantomjs"
task :test => [:phantomjs, :dist, :vendor] do |t, args|

  if exec_test
    err "Tests Passed".green
  else
    err "Tests Failed".red
    exit(1)
  end
end

task :phantomjs do
  unless system("which phantomjs > /dev/null 2>&1")
    abort "PhantomJS is not installed. Download from http://phantomjs.org"
  end
end


desc "tag/upload release"
task :release, [:version] => :test do |t, args|
  unless args[:version] and args[:version].match(/^[\d]+\.[\d]+\.[\d].*$/)
    raise "SPECIFY A VERSION curent version: #{TAXI_VERSION}"
  end
  File.open("./version.rb", "w") do |f| 
    f.write %|TAXI_VERSION = "#{args[:version]}"|
  end

  system "git add version.rb"
  system "git commit -m 'bumped version to #{args[:version]}'"
  system "git tag #{args[:version]}"
  system "git push origin master"
  system "git push origin #{args[:version]}"
  Rake::Task[:upload].invoke
end

desc "upload versions"
task :upload => :test do
  load "./version.rb"
  uploader = GithubUploader.setup_uploader
  GithubUploader.upload_file uploader, "taxi-#{TAXI_VERSION}.js", "Taxi #{TAXI_VERSION}", "dist/taxi.js"
  GithubUploader.upload_file uploader, "taxi-#{TAXI_VERSION}-spade.js", "Taxi #{TAXI_VERSION} (minispade)", "dist/taxi-spade.js"
  GithubUploader.upload_file uploader, "taxi-#{TAXI_VERSION}.html", "Taxi #{TAXI_VERSION} (html_package)", "dist/taxi.html"

  GithubUploader.upload_file uploader, 'taxi-latest.js', "Current Taxi", "dist/taxi.js"
  GithubUploader.upload_file uploader, 'taxi-latest-spade.js', "Current Taxi (minispade)", "dist/taxi-spade.js"
end
