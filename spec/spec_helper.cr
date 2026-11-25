require "spec"
require "../src/symphony"

# No log output in the tests. Use LOG_LEVEL=debug to see it.
Log.setup_from_env(default_level: :none)
