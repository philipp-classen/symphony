# symphony

TODO: Write a description here

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     symphony:
       github: philipp-classen/symphony
   ```

2. Run `shards install`

## Usage

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

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/philipp-classen/symphony/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Philipp Claßen](https://github.com/philipp-classen) - creator and maintainer
