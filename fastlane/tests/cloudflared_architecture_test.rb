require "fileutils"
require "minitest/autorun"
require "open3"
require "tmpdir"

def default_platform(*)
  nil
end

def desc(*)
  nil
end

def lane(*)
  nil
end

def platform(*)
  nil
end

def sh(command, **)
  output, status = Open3.capture2e(command)
  raise output unless status.success?
  output
end

module UI
  def self.success(*)
    nil
  end

  def self.user_error!(message)
    raise message
  end
end

load File.expand_path("../Fastfile", __dir__)

class CloudflaredArchitectureTest < Minitest::Test
  def test_bundle_requires_every_daemon_architecture
    Dir.mktmpdir("afto-cloudflared-test") do |folder|
      app = File.join(folder, "Fixture.app")
      FileUtils.mkdir_p(File.join(app, "Contents", "MacOS"))
      FileUtils.mkdir_p(File.join(app, "Contents", "Resources"))
      File.write(File.join(folder, "main.c"), "int main(void) { return 0; }\n")
      output, status = Open3.capture2e("xcrun", "clang", "-arch", "arm64", "-arch", "x86_64", File.join(folder, "main.c"), "-o", File.join(app, "Contents", "MacOS", "Fixture"))
      assert status.success?, output
      ENV["CLOUDFLARED_PATH"] = File.join(app, "Contents", "MacOS", "Fixture")
      bundle_cloudflared(app)
      assert File.executable?(File.join(app, "Contents", "Resources", "cloudflared"))
      output, status = Open3.capture2e("lipo", "-thin", "arm64", ENV.fetch("CLOUDFLARED_PATH"), "-output", File.join(folder, "thin"))
      assert status.success?, output
      ENV["CLOUDFLARED_PATH"] = File.join(folder, "thin")
      assert_raises(RuntimeError) { bundle_cloudflared(app) }
    end
  end
end
