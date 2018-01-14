@section4 @section4_1 @client
Feature: Validate handshake response
  The handshake response from the server must be validated.

  @4_1_P5 @must
  Scenario: Waiting for a handshake response
     When the client has sent a handshake
     Then the client must wait for a handshake response before sending data

  @4_1_P5 @must
  Scenario: Validating the handshake response
     When the client has received a handshake response
     Then the client must validate the server's response

  @4_1_HandshakeResponse_1 @must
  Scenario: Handshake response code that is not 101 Switching Protocols
     When the status code is not 101 Switching Protocols
     Then the client handles the response per HTTP procedures

  @4_1_HandshakeResponse_2 @must
  Scenario: Handshake response does not contain an Upgrade header field
     When the server's response does not contain the "Upgrade" header field
     Then the client must fail the WebSocket connection

  @4_1_HandshakeResponse_2 @must
  Scenario: Handshake response contains an invalid Upgrade header field
    Given that the server's response contains the "Upgrade" header field
     When the value does not contain the "websocket" keyword
     Then the client must fail the WebSocket connection

  @4_1_HandshakeResponse_3 @must
  Scenario: Handshake response does not contain an Connection header field
     When the server's response does not contain the "Connection" header field
     Then the client must fail the WebSocket connection

  @4_1_HandshakeResponse_3 @must
  Scenario: Handshake response contains an invalid Connection header field
    Given that the server's response contains the "Connection" header field
     When the value does not contain the "Upgrade" token
     Then the client must fail the WebSocket connection

  @4_1_HandshakeResponse_4 @must
  Scenario: Handshake response does not contain an Sec-WebSocket-Accept header field
     When the server's response does not contain the "Sec-WebSocket-Accept" header field
     Then the client must fail the WebSocket connection

  @4_1_HandshakeResponse_4 @must
  Scenario: Handshake response contains an invalid Sec-WebSocket-Accept header field
    Given that the server's response contains the "Sec-WebSocket-Accept" header field
     When the value does not match the expected Sec-WebSocket-Accept value
     Then the client must fail the WebSocket connection

  @4_1_HandshakeResponse_5 @must
  Scenario: Handshake response with Sec-WebSocket-Extensions
    Given that the server's response contains the "Sec-WebSocket-Extensions" header field
     When the field indicates the use of an extension that was not present in the client's handshake
     Then the client must fail the WebSocket connection

  @4_1_HandshakeResponse_6 @must
  Scenario: Handshake response with Sec-WebSocket-Protocol
    Given that the server's response contains the "Sec-WebSocket-Protocol" header field
     When the field indicates the use of a subprotocol that was not present in the client's handshake
     Then the client must fail the WebSocket connection

  @4_1_P6 @must
  Scenario: Handshake response is invalid
     When the server's response is invalid
     Then the client must fail the WebSocket connection

  @4_1_8 @must
  Scenario: Handshake response is valid
     When the server's response is valid
     Then the WebSocket connection is in the OPEN state

  @4_1_8 @must
  Scenario: Handshake response has extensions in use
     When the WebSocket connection is in the OPEN state
     Then the value "Extension In Use" is a possibly empty value equal to the "Sec-WebSocket-Extensions" header field in the server's response

  @4_1_8 @must
  Scenario: Handshake response has subprotocols in use
     When the WebSocket connection is in the OPEN state
     Then the value "Subprotocols In Use" is a value equal to the "Sec-WebSocket-Protocol" header field in the server's response or null

  @4_1_8 @must
  Scenario: Handshake response has cookies set
     When the server's handshake response contains header fields indicating cookies that should be set
     Then these cookies are referred to as "Cookies Set During the Server's Opening Handshake"
