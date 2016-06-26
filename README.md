# scribe

A package for writing logs to the console or to a rotating file.

## Usage

```
var server = new LoggingServer([new RotatingLoggingBackend("api.log"")]);
await server.getNewTarget().bind(logger);
await server.start();
```
