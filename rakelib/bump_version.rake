require 'erb'

desc "bump version"
task :bump_version do
  def env(key)
    value = ENV[key].to_s.strip
    fail "Please specify #{key}" if value == ''
    value
  end

  current_version = env('CURRENT_VERSION')
  version_to_release = env('VERSION_TO_RELEASE')
  next_version = env('NEXT_VERSION')

  if [current_version, version_to_release, next_version].sort != [current_version, version_to_release, next_version]
    fail "CURRENT_VERSION VERSION_TO_RELEASE and NEXT_VERSION don't seem right"
  end

  remote_name = env('REMOTE_NAME')
  repo_url = `git config --get remote.#{remote_name}.url`.strip

  $stderr.puts "*** Setting up gh-pages branch for next release"
  rm_rf "build"
  sh("git clone #{repo_url} build --branch gh-pages --depth 1 --quiet")

  cd "build" do
    rm_rf 'current'
    ln_sf version_to_release, "./current"

    open('index.html', 'w') do |f|
      erb = ERB.new(File.read("#{File.dirname(__FILE__)}/root.html.erb"), nil, '-')
      html = erb.result(binding)
      f.puts(html)
    end
    sh("git add current index.html")
    sh("git commit -m 'Point current to new version'")
    sh("git push")
  end

  $stderr.puts("*** Creating branch for - #{version_to_release}")
  sh("git checkout master")
  sh("git checkout -b release-#{version_to_release}")
  sh("git push #{remote_name} release-#{version_to_release}")
  sh("git checkout master")

  $stderr.puts "Bumping version in lib/version.rb"
  open('rakelib/version.rake', 'w') do |f|
    f.puts("# this file is updated automatically using a rake task, any changes will be lost")
    f.puts("GOCD_VERSION = '#{next_version}'")
  end

  sh('git add rakelib/version.rake')
  sh("git commit -m 'bump version to #{next_version}'")
  sh("git push #{remote_name} master")
end
