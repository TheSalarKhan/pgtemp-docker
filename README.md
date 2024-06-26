# pgtemp as a Docker container

pgtemp (https://github.com/boustrophedon/pgtemp) is an amazing project that runs a server which spawns a new postgres instance on every connection.
This allows it to be used for scenarios like unit-tests where each tests requires its own empty database.

This repository just runs pgtemp inside a container and exposes it on port 6543. The directory used for postgres data is `/tmp` within the container, and that is mounted on a ramdisk using `tmpfs` so anything that writes into the database will write into RAM. This was just done to make things a little bit fast while assuming that a single test won't create huge amounts of data.

## Usage

The usage is pretty simple. Just run `docker-compose up` and it will build and spin up a container that listens on port `6543` on your host.

Now you can connect to this database using the connection string: `postgresql://pguser:pgpass@localhost:6544/tempdb`

Or

```
host: localhost
port: 6543
user: pguser
password: pgpass
dbname: tempdb
```

Remember! each connection you make to this database will give you a new postgres server, even simultaneous connections will point to two different postgres servers.

# Contribution & Queries

I've tried to keep the design as simple as possible. But please do raise issues if you have any questions. Or raise PRs if you have a cool suggestion. Thanks!

# LICENSE

MIT. Do whatever you want with this.

