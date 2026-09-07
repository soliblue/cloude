require "shellwords"

$lanes = {}
$uploads = 0
$archives = 0
$keys = []
def default_platform(*)
  nil
end
def desc(*)
  nil
end
def platform(name, &block)
  block.call if name == :ios
end
def lane(name, &block)
  $lanes[name] = block
end
def app_store_connect_api_key(**)
  { fixture: true }
end
def latest_testflight_build_number(**)
  237
end
def increment_build_number(**arguments)
  raise "Build number" unless arguments[:build_number] == 238
end
def update_code_signing_settings(**)
  nil
end
def build_app(**arguments)
  archive = Shellwords.split(arguments[:xcargs])
  export = Shellwords.split(arguments[:export_xcargs].to_s) + archive
  raise "Different export credentials" unless archive == export
  key = archive[archive.index("-authenticationKeyPath") + 1]
  raise "Key contents" unless File.read(key) == "fixture-key"
  raise "Key permissions" unless File.stat(key).mode & 0777 == 0600
  $keys << key
  $archives += 1
end
def upload_to_testflight(**arguments)
  raise "Wrong authentication" unless arguments[:api_key] == { fixture: true }
  $uploads += 1
end
ENV["APP_STORE_CONNECT_API_KEY_ID"] = "fixture-id"
ENV["APP_STORE_CONNECT_API_ISSUER_ID"] = "fixture-issuer"
ENV["APP_STORE_CONNECT_API_KEY_CONTENT"] = "fixture-key"
load File.expand_path("../Fastfile", __dir__)
[false, "false"].each { |value| $lanes[:beta_local].call(upload: value) }
raise "Archive-only uploaded" unless $uploads == 0 && $archives == 2
$lanes[:beta_local].call({})
raise "Explicit release did not upload" unless $uploads == 1 && $archives == 3
raise "Signing key was not removed" unless $keys.none? { |key| File.exist?(key) }
puts "PASS archive-only never uploads; local archive/export authentication and temporary key cleanup"
