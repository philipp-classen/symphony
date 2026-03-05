require "./symphony/minimal"
require "./symphony/http"

module Symphony
  Log     = ::Log.for(Symphony)
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
end
