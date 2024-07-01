module Symphony
  class TimeoutException < Exception
    def initialize(message = "Operation timed out")
      super(message)
    end
  end

  class AwaitableSignal
    @done = Channel(Int32).new

    # Marks the signal as completed. All fibers that are waiting for it will be waken up.
    #
    # Calling it multiple times is safe. The first call will return `true`, but
    # all calls after that will return `false`.
    def done! : Bool
      @done.close
    end

    # Nonblocking check if the signal is completed.
    def done? : Bool
      @done.closed?
    end

    # Block until completed. If it is already completed, it will return immediately.
    def wait : Nil
      @done.receive?
    end

    # Waits for completions (0 disables the timeout).
    # If it is already completed, it will return immediately.
    def wait_or_timeout(max_wait : Time::Span?) : Nil
      if !max_wait || max_wait.zero?
        wait
      else
        select
        when @done.receive?
        when timeout max_wait
          raise TimeoutException.new("Operation timed out after #{max_wait}")
        end
      end
    end
  end
end
