require "../spec_helper"
require "../support/one_writer_app"

# The app for the unit tests. It records the hard kill: the real one would
# end the test run.
private class SpyApp < OneWriterApp
  getter stopped = Symphony::AwaitableSignal.new
  getter hard_killed = Symphony::AwaitableSignal.new

  # Runs an app in the background and stops it with a signal.
  def self.shut_down(stop : FakeWriter::Stop) : SpyApp
    app = new(stop)
    spawn do
      # Not INT or TERM: the handler stays, and they must still end the test run.
      app.run_and_stop_with(Signal::USR1)
      app.stopped.done!
    end
    app
  end

  protected def hard_kill! : Nil
    @hard_killed.done!
  end
end

describe Symphony::Application do
  describe "shutdown on a signal" do
    it "stops when all services stop" do
      app = SpyApp.shut_down(:clean)

      app.stopped.wait_or_timeout(1.second)
    end

    it "stops after a forced shutdown without errors" do
      app = SpyApp.shut_down(:stuck)

      app.stopped.wait_or_timeout(1.second)
    end

    it "does a hard kill if the forced shutdown fails" do
      app = SpyApp.shut_down(:unstoppable)

      app.hard_killed.wait_or_timeout(1.second)
      app.stopped.done?.should be_false
    end
  end
end
