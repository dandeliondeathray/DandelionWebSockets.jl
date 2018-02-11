@section4 @section4_4 @client @server @inapplicable
Feature: Section 4.4: Supporting Multiple Versions of WebSocket Protocol
  A client and server may choose to support multiple versions of the protocol.

  @4_4 @must
  Scenario: Requested version is unsupported
    Given that the client requests a WebSocket protocol version
     When the server does not support the provided WebSocket protocol version
     Then the server must response with a "Sec-WebSocket-Version" field listing all versions is supports
      And the HTTP status code must be an appropriate error code
