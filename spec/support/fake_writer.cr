# A writer for the tests. `Stop` selects how it stops, and thus how symphony
# ends after a signal:
#
# | Stop        | Graceful stop | Forced stop | Symphony ends with         |
# |-------------|---------------|-------------|----------------------------|
# | Clean       | works         | not needed  | normal stop                |
# | Stuck       | hangs         | works       | stop after forced shutdown |
# | Unstoppable | hangs         | fails       | hard kill                  |
class FakeWriter < Symphony::BackgroundService
  enum Stop
    Clean
    Stuck
    Unstoppable
  end

  getter started = Symphony::AwaitableSignal.new

  def initialize(@stop : Stop)
  end

  def start : Nil
    @started.done!
  end

  def interrupt : Nil
  end

  def alive? : Bool
    true
  end

  # Symphony calls `join` without a timeout in the graceful stop. If that
  # call hangs, it calls `join` again, with a timeout, in a different fiber
  # (the forced stop). The length of the timeout is not used.
  def join(timeout : Time::Span? = nil) : Nil
    return if @stop.clean?

    if timeout.nil?
      sleep # graceful stop: hangs (no time: this fiber blocks forever)
    elsif @stop.unstoppable?
      raise "cannot stop" # forced stop: fails
    end
  end
end
