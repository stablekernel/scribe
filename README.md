# scribe

A package for writing logs to the console or to a rotating file.

## Usage

```
var server = new LoggingServer([new RotatingLoggingBackend("api.log"")]);
server.getNewTarget().bind(logger);
await server.start();
```
