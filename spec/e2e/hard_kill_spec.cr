require "../spec_helper"
require "../support/e2e_test_app"
require "../support/one_writer_app"

# The application with the real hard kill, which ends the process: run it
# only in an `E2ETestApp`.
private class HardKillApp < OneWriterApp
end

unstoppable_app = E2ETestApp.define "unstoppable" do
  Log.setup(:info) # the test reads the log
  HardKillApp.new(:unstoppable).run_and_stop_with(Signal::TERM)
end

describe "Symphony::Application (e2e)" do
  it "ends the process with a hard kill if the forced shutdown fails" do
    status, output = unstoppable_app.run_as_process

    status.normal_exit?.should be_true # SIGTERM did not kill it
    output.should contain("Forcing a hard kill")
    output.should_not contain("Application stopped.")
  end
end
