module Symphony
  class HealthCheck
    @application_ready = false
    @health_checks_stopped = false
    @healthy_in_a_row_counter = 0
    @internal_errors = 0

    @log : ::Log = Log.for(HealthCheck)

    def initialize(interval = 5.seconds)
      spawn do
        @log.debug { "Periodic health checks running every 5 seconds" }
        loop do
          sleep interval.seconds
          break if @health_checks_stopped
          run_health_check
        end
      end
    end

    # It will not make the health check fail, but the next health check will produce a warning.
    def internal_error!
      @log.error { "Internal errors detected!" } if @internal_errors == 0
      @internal_errors += 1
    end

    # to be used by subclasses
    def ok? : Bool
      true
    end

    # to be used by subclasses
    def total_concerning_events : Int32
      0
    end

    # to be used by subclasses
    def reset_counters : Nil
    end

    def application_ready!
      @application_ready = true
    end

    def stop_health_checks
      unless @health_checks_stopped
        @health_checks_stopped = true
        run_health_check
        @log.debug { "Periodic health checks stopped" }
      end
    end

    private def run_health_check
      unless @application_ready
        @log.warn { "System is unhealthy (application not started yet)" }
        @healthy_in_a_row_counter = 0
        return
      end

      unless ok?
        @log.warn { "System is unhealthy (failed health checks)" }
        @healthy_in_a_row_counter = 0
        return
      end

      bad_events = @internal_errors + total_concerning_events
      if bad_events > 0
        @log.warn { "System is healthy, but it is experiencing problems (#{bad_events} events since the last check)" }
        return
      end

      if @healthy_in_a_row_counter == 0
        @log.info { "System is healthy" }
      else
        @log.debug { "System is healthy (passed #{@healthy_in_a_row_counter + 1} in a row)" }
      end
      @healthy_in_a_row_counter += 1
    ensure
      @internal_errors = 0
      reset_counters
    end
  end
end
