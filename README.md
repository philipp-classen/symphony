# Symphony

Streamlines the startup and safe shutdown of Crystal servers that take
inputs (e.g. queues, HTTP requests) and stream them to various outputs.
It is not intended for classical HTTP servers that take a request and
respond directly, but rather for asynchronous processing.

The core idea is to let the application define a list of readers (input)
and writers (output), where each reader and writer will run independently.

The framework will take care of the proper startup (first the writers,
then the readers), and the safe shutdown (stopping first the readers,
then the writers). It will also handle signals like SIGINT or SIGTERM.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     symphony:
       github: philipp-classen/symphony
   ```

2. Run `shards install`

## Usage

This is a minimal example to illustrate what to setup a basic server.
It is not very useful, since it does not define a writer, but it
shows the basic structure of a Symphony application.

```crystal
require "symphony"

class Application < Symphony::Application
  Log = ::Log.for("test-app")

  def create_input_readers : Array(Symphony::BackgroundService)
    server = Symphony::HttpServer.new do |ctx|
      ctx.response.content_type = "text/plain"
      ctx.response.print "Hello world, got #{ctx.request.path}!"
    end
    [server] of Symphony::BackgroundService
  end

  def create_output_writers : Array(Symphony::BackgroundService)
    [] of Symphony::BackgroundService
  end
end

Log.setup_from_env
APP = Application.new
APP.run
```

## Development

There are currently no tests.

## Contributing

1. Fork it (<https://github.com/philipp-classen/symphony/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Philipp Claßen](https://github.com/philipp-classen) - creator and maintainer
