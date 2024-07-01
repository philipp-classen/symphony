require "log"
require "http/server"

module Symphony
  class HttpServer < BackgroundService
    @pending_requests = 0
    @started = false
    @shutdown_complete = AwaitableSignal.new
    @health_check : HealthCheck? = nil

    def initialize(@host = "127.0.0.1", @port = 8080, @log = ::Log.for("symphony").for("http"), &handler : HTTP::Server::Context ->)
      @server = HTTP::Server.new do |ctx|
        @pending_requests += 1
        begin
          handler.call(ctx)
        rescue e : Exception
          @health_check.try &.internal_error!
          raise e
        ensure
          @pending_requests -= 1
          @log.debug { "#{ctx.request.method} #{ctx.request.path} ==> #{ctx.response.status}" }
        end
      end
    end

    def start : Nil
      spawn do
        Log.info { "Listening on http://#{@host}:#{@port}..." }
        @started = true
        @server.listen(@host, @port)
        Log.info { "Shutdown: no longer accepting new connection on http://#{@host}:#{@port} (entering grace period)" }

        # Give the already accepted but not exected requests a chance to run.
        # If they count as pending, it will delay the shutdown of the writer.
        sleep 0

        counter = 0
        while @pending_requests > 0
          Log.info { "#{@pending_requests} requests left..." } if counter % 100 == 0
          counter += 1
          sleep 10.milliseconds
        end
        Log.info { "HTTP server successfully shut down (no more open requests)" }

        @shutdown_complete.done!
      end
    end

    def interrupt : Nil
      @server.close unless @server.closed?
    end

    def join(timeout : Time::Span? = nil) : Nil
      @shutdown_complete.wait_or_timeout(timeout)
    end

    def alive? : Bool
      @started && !@shutdown_complete.done?
    end
  end
end
