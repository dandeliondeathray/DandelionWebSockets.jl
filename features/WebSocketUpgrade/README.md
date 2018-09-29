# WebSocket Upgrade Specification
The WebSocket handshake uses HTTP, as defined in RFC 2616. The handshake uses only a subset of HTTP,
as it uses only a the GET method, and expects a response with status 101 and no body. While all
requirements are available in prose in the RFC, writing them as Gherkin makes them identifiable.

The features are divided into the chapters of the RFC. Some chapters contain no requirements, and
are omitted here.

Features and scenarios that are inapplicable to the WebSocket handshake will be marked as
`@inapplicable`.

Features and scenarios that are applicable, but not yet implemented, will be marked as `@wip`.

