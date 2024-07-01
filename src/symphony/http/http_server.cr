require "log"
require "http/server"

module Symphony
  class HttpServer < BackgroundService
    Log       = Symphony::Log.for(HttpServer)
    AccessLog = Log.for("request")

    @pending_requests = 0
    @started = false
    @shutdown_complete = AwaitableSignal.new

    # This allows to log the first requests fully, but afterwards skip
    # them unless they seems important (defined by `skip_logging`).
    property max_request_to_always_log = 1000_u64
    @request_counter = 0_u64

    def initialize(@host = "127.0.0.1", @port = 8080, @health_check : HealthCheck? = nil, &handler : HTTP::Server::Context ->)
      @server = HTTP::Server.new do |ctx|
        @pending_requests += 1
        begin
          handler.call(ctx)
          @request_counter &+= 1
          if @request_counter > max_request_to_always_log && skip_logging(ctx)
            AccessLog.debug { format_access_log(ctx) }
          else
            AccessLog.info { format_access_log(ctx) }
          end
        rescue e : Exception
          @health_check.try &.internal_error!
          begin
            ctx.response.respond_with_status(HTTP::Status::INTERNAL_SERVER_ERROR, "failed")
          rescue
            ctx.response.status = HTTP::Status::INTERNAL_SERVER_ERROR
          end
          AccessLog.error(exception: e) { format_access_log(ctx) }
        ensure
          @pending_requests -= 1
        end
      end
    end

    def skip_logging(ctx) : Bool
      ctx.response.status.success?
    end

    def format_access_log(ctx : HTTP::Server::Context) : String
      %("#{ctx.request.method} #{ctx.request.path}" #{ctx.response.status_code})
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
