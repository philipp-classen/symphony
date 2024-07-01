require "log"

module Symphony
  abstract class Application
    @writers = Array(BackgroundService).new
    @readers = Array(BackgroundService).new

    @shutdown = AwaitableSignal.new
    @shutdown_initiated = false
    @errors_during_shutdown = false

    def initialize(@log = ::Log.for("symphony"))
    end

    # To overwrite, use the following pattern:
    #
    # ```
    # class HealthCheck < Symphony::HealthCheck
    #   ...
    # end
    #
    # class Application < Symphony::Application
    #   getter health_check = HealthCheck.new
    #   ...
    # end
    # ```
    def health_check : HealthCheck?
      nil
    end

    def run(*, install_default_signal_handler = true)
      if install_default_signal_handler
        shutdown_on_signal
      end

      @log.debug { "Starting up writers..." }
      @writers = create_output_writers
      if @writers.empty?
        @log.debug { "No writer configured." }
      else
        @writers.each &.start
        @log.debug { "Starting up writers...DONE (#{@writers.size} in total)" }
      end

      @log.debug { "Starting up readers..." }
      @readers = create_input_readers
      if @readers.empty?
        @log.debug { "No readers configured." }
      else
        @readers.each &.start
        @log.debug { "Starting up readers...DONE (#{@readers.size} in total)" }
      end

      health_check.try &.application_ready!
      @log.info { "Starting application...DONE" }

      @shutdown.wait
      health_check.try &.stop_health_checks
      @log.info { "Application stopped." }

      sleep 0 # give the event loop a chance to clear (flushes the logger)
    end

    abstract def create_output_writers : Array(BackgroundService)
    abstract def create_input_readers : Array(BackgroundService)

    def shutdown_on_signal(*,
                           signals = {Signal::INT, Signal::TERM},
                           timeouts = {
                             graceful:  5.seconds,
                             forced:    30.seconds,
                             hard_kill: 40.seconds,
                           })
      signals.each do |signal|
        @log.debug { "Installing signal handler for #{signal}" }
        signal.trap do
          @log.info { "Signal #{signal} detected..." }
          done = Channel(Int32).new
          spawn do
            @log.info { "Shutting down the server gracefully..." }
            if graceful_shutdown
              @log.info { "Shutting down the server gracefully...SUCCESS" }
            else
              @log.warn { "Shutting down the server gracefully...FAILED" }
            end
            done.send(1)
          end

          select
          when done.receive
          when timeout timeouts[:graceful]
            @log.warn { "Shutdown is taking too long. Forcing the shutdown (#{timeouts})..." }
            spawn do
              sleep timeouts[:hard_kill]
              @log.error { "Even the forced shutdown failed. Forcing a hard kill, even it means losing data." }
              sleep 1.seconds
              Process.exit(0)
            end
            force_shutdown(timeout: timeouts[:forced])
          end
        end
      end
    end

    def graceful_shutdown : Bool
      if @shutdown_initiated
        @log.info { "Shutdown already in progress." }
        @shutdown.wait
      else
        @log.info { "Graceful shutdown initiated..." }
        @shutdown_initiated = true

        stop_services_gracefully(@readers)
        @log.info { "All readers have been stopped. From this point on, no new messages should be accepted." }
        stop_accepting_new_messages

        stop_services_gracefully(@writers)
        @log.info { "All writer have been stopped." }

        if @shutdown.done!
          @log.info { "Shutdown completed" }
        end
      end

      !@errors_during_shutdown
    end

    def stop_accepting_new_messages
      # TODO: should a message queue be implemented her or left out?
      # if @message_queue.close
      #   @log.info { "Message queue has been closed." }
      # else
      #   @log.warn { "Message queue has been already closed." }
      # end
    end

    def force_shutdown(timeout = 30.seconds, min_reader_timeout = 2.seconds, min_writer_timeout = 3.seconds)
      if @shutdown.done?
        @log.debug { "Ignoring force_shutdown (already terminated)" }
        return
      end

      if timeout < min_reader_timeout + min_writer_timeout
        @log.warn { "Invidual timeouts (min_reader_timeout=#{min_reader_timeout}, min_writer_timeout=#{min_writer_timeout}) can exceed the total timeout (#{timeout})" }
      end

      # since we have a fixed time budget for the shutdown, try not to burn everything on the inputs
      started_at = Time.utc
      reader_timeout = {min_writer_timeout, timeout * 0.3}.max
      kill_services(@readers, reader_timeout)

      if @errors_during_shutdown
        @log.warn { "Failed to gracefully shut down readers. New message might still be ariving. Proceeding with shutting down writes anyways." }
      end
      stop_accepting_new_messages

      remaining_budget = timeout - (Time.utc - started_at)
      writer_timeout = {min_writer_timeout, remaining_budget}.max
      kill_services(@writers, writer_timeout)

      if @errors_during_shutdown
        @log.info { "Forced shutdown completed successfully. No errors were detected." }
      else
        @log.warn { "Forced shutdown completed but with errors." }
      end
    end

    private def stop_services_gracefully(services : Array(BackgroundService))
      services.each &.interrupt
      services.each &.join
    end

    private def kill_services(services : Array(BackgroundService), timeout : Time::Span)
      services.each &.interrupt
      all_done = services.map do |service|
        signal = AwaitableSignal.new
        spawn do
          begin
            service.join(timeout)
          rescue e
            @log.error(exception: e) { "Failed to shutdown service (timeout=#{timeout})." }
            @errors_during_shutdown = true
          end
          signal.done!
        end
        signal
      end
      all_done.each &.wait
    end
  end
end
