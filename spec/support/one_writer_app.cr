require "./fake_writer"

# An application with one `FakeWriter` and short shutdown timeouts.
#
# It is abstract because the hard kill ends the process. Each kind of test
# has its own subclass:
#
# - `SpyApp` (`spec/unit`) records the hard kill.
# - `HardKillApp` (`spec/e2e`) has the real hard kill.
abstract class OneWriterApp < Symphony::Application
  # `forced` has no effect on the test time: the forced stop of the fake
  # writer is immediate.
  TIMEOUTS = {graceful: 50.milliseconds, forced: 1.second, hard_kill: 100.milliseconds}

  def initialize(stop : FakeWriter::Stop)
    @writer = FakeWriter.new(stop)
  end

  # Runs the app and sends *signal* to this process when the writer has
  # started. Returns when the app has stopped.
  def run_and_stop_with(signal : Signal) : Nil
    shutdown_on_signal(signals: {signal}, timeouts: TIMEOUTS)
    spawn do
      @writer.started.wait
      Process.signal(signal, Process.pid)
    end
    run(install_default_signal_handler: false)
  end

  def create_input_readers : Array(Symphony::BackgroundService)
    [] of Symphony::BackgroundService
  end

  def create_output_writers : Array(Symphony::BackgroundService)
    [@writer] of Symphony::BackgroundService
  end
end
