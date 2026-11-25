# A small program for the E2E tests. It runs as a process of its own. Use it
# for code that ends the process.
#
# ```
# unstoppable_app = E2ETestApp.define "unstoppable" do
#   # the code of the app
# end
#
# status, output = unstoppable_app.run_as_process # in a test
# ```
#
# How it works: the spec binary has two uses.
#
# - Started as usual, it runs the tests. This is the test process.
# - Started with the name of an app in `SYMPHONY_E2E_TEST_APP_NAME`, it runs
#   only the block of that app, then it stops. This is the process of the app.
#
# `run_as_process` starts the spec binary again, in the second way:
#
# ```text
# spec binary                                            runs the tests
#   spec binary, SYMPHONY_E2E_TEST_APP_NAME=unstoppable  runs only the block
# ```
#
# Thus an app can use all the code of the tests, and no compiler is necessary
# when the tests run.
#
# To see the output of an app, start it by hand:
# `SYMPHONY_E2E_TEST_APP_NAME=unstoppable crystal spec spec/e2e`
class E2ETestApp
  NAME_ENV = "SYMPHONY_E2E_TEST_APP_NAME"
  TIMEOUT  = 10.seconds

  @@places = {} of String => String

  # Defines an app. Call it at the top level of a spec file. The name must be
  # unique.
  #
  # In the test process, it returns the app and does not run the block.
  # In the process of the app, it runs the block and then ends the process.
  def self.define(name : String, file = __FILE__, line = __LINE__, &) : E2ETestApp
    place = "#{Path[file].relative_to(Dir.current)}:#{line}"
    if first = @@places[name]?
      abort "Duplicate E2E test app '#{name}': #{first} and #{place}"
    end
    @@places[name] = place

    if app_process?(name)
      # We are in the spawned process that runs the test app now
      yield

      # Not `exit`: Crystal's `spec` runs the tests in an `at_exit` handler,
      # and `exit` starts those handlers.
      Process.exit(0)
    end
    new(name)
  end

  # True if this process is the process of the app *name*:
  # `run_as_process` started it with that name in the environment.
  private def self.app_process?(name : String) : Bool
    ENV[NAME_ENV]? == name
  end

  private def initialize(@name : String)
  end

  # Starts the app as a process and waits for its exit. Returns the exit
  # status and the output.
  def run_as_process : {Process::Status, String}
    spec_binary = Process.executable_path || raise "Cannot find the spec binary"
    output = IO::Memory.new
    process = Process.new(spec_binary, env: {NAME_ENV => @name}, output: output, error: output)
    exited = Channel(Process::Status).new(1)
    spawn { exited.send(process.wait) }

    select
    when status = exited.receive
      {status, output.to_s}
    when timeout(TIMEOUT)
      process.signal(Signal::KILL)
      raise "The E2E test app '#{@name}' did not stop in #{TIMEOUT}"
    end
  end
end

# A process with an unknown app name must not run the tests: it would start itself again.
Spec.before_suite do
  if name = ENV[E2ETestApp::NAME_ENV]?
    abort "Unknown E2E test app: #{name}"
  end
end
