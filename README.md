# Rackget

Like curl for your Rack application

A command line utility to boot a Rack app and makes a request to it, without starting a server.

## Installation

```bash
gem install rackget
```

## Usage

```bash
# GET request (loads config.ru from current directory)
rackget /users

# Full URL (sets Host header)
rackget http://localhost/users?page=2

# Other HTTP methods
rackget -X POST -d 'name=foo' /users
rackget -X PUT -d '{"name":"bar"}' /users/1
rackget -X DELETE /users/1

# Custom headers
rackget -H 'Content-Type: application/json' -X POST -d '{"name":"foo"}' /users

# Show status and response headers
rackget -i /users

# Specify a rackup file
rackget -r myapp.ru /users

# Pipe request body from stdin
echo '{"name":"foo"}' | rackget -X POST /users
```

## License

MIT
