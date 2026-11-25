# Symphony

Simplifies the startup and safe shutdown of Crystal servers that process inputs
(such as queues and HTTP requests) and stream them to various outputs.
Unlike traditional HTTP servers that directly respond to requests, this framework
is designed for asynchronous processing.

The core idea is to let the application define a list of readers (input)
and writers (output), where each reader and writer will run independently.

The framework will take care of the proper startup (first the writers,
then the readers) and the safe shutdown (stopping first the readers,
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

Here is a minimal example to illustrate how to set up a basic server. While
this example does not include a writer and may not be practically useful,
it demonstrates the basic structure of a Symphony application.

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

| Tests | Folder | Command |
|---|---|---|
| Unit tests | `spec/unit` | `make test` |
| E2E tests | `spec/e2e` | `make test-e2e` |
| All tests | `spec` | `make test-all` |

Unit tests run in the test process. They are fast.

E2E tests start a test app as a process of its own. Use them for code that
ends the process. They are slower.

Helpers and fakes for the tests are in `spec/support`.

Before a commit, run the format check and the linter (Ameba). The linter
needs `shards install` one time:

```
make format-check
make linter
```

`make format-apply` and `make linter-fix` correct what they can.

### How the E2E tests work

Some code ends the process, for example the hard kill. A test cannot run
such code in the test process. It needs a second process.

The second process is the test program itself. It has two uses:

- Started as usual, it runs the tests.
- Started with `SYMPHONY_E2E_TEST_APP_NAME=<name>`, it runs only the code of
  the test app with that name, and then it stops.

An E2E test defines a test app and starts it as a process:

```crystal
unstoppable_app = E2ETestApp.define "unstoppable" do
  # the code of the app; here it ends with a hard kill
end

it "ends the process with a hard kill" do
  status, output = unstoppable_app.run_as_process
  # ...
end
```

Thus a test app can use all the code of the tests. No second program and
no compiler are necessary when the tests run.

To see the output of a test app, start it by hand:

```
SYMPHONY_E2E_TEST_APP_NAME=unstoppable crystal spec spec/e2e
```

The details are in `spec/support/e2e_test_app.cr`.

## Contributing

1. Fork it (<https://github.com/philipp-classen/symphony/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Philipp Claßen](https://github.com/philipp-classen) - creator and maintainer
