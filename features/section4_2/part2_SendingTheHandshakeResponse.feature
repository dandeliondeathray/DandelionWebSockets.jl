@section4 @section4_2 @server @irrelevant
Feature: Send the handshake response
  The opening handshake details how the server handles a new connection.

  @4_2_2_P1 @must
  Scenario: Sending a handshake response
     When the client has sent a a WebSocket handshake to the server
     Then the server must send a handshake response

  @4_2_2_SendingHandshakeResponse_1 @must
  Scenario: Valid TLS connection
    Given the connection is using TLS
     When the handshake is successful
     Then all further communication must run through an encrypted tunnel

  @4_2_2_SendingHandshakeResponse_1 @must
  Scenario: Invalid TLS connection
    Given the connection is using TLS
     When the handshake is invalid
     Then the connection must be closed

  @4_2_2_SendingHandshakeResponse_2 @may
  Scenario: Server may perform additional client authentication
     When the client has sent a handshake
     Then the server may perform additional client authentication

  @4_2_2_SendingHandshakeResponse_3 @may
  Scenario: Server may redirect the client
     When the client has sent a handshake
     Then the server may redirect the client using a 3xx status code

  @4_2_2_SendingHandshakeResponse_4 @may
  Scenario: Server may use the Origin header field
     When an "Origin" header field is present in the handshake
     Then the server may use this information to accept or deny the connection

  @4_2_2_SendingHandshakeResponse_4 @may
  Scenario: Server does not accept Origin header field
    Given an "Origin" header field in the client handshake
     When the Origin header field is deemed unacceptable
     Then the server must return an appropriate HTTP error code

  @4_2_2_SendingHandshakeResponse_4 @must
  Scenario: Valid version field
     When a "Version" header field is in the client handshake
     Then the version must the acceptable version 13

  @4_2_2_SendingHandshakeResponse_4 @must
  Scenario: Invalid version field
    Given a "Version" header field in the client handshake
     When the version is not 13
     Then the server must abort the handshake

  @4_2_2_SendingHandshakeResponse_4 @must
  Scenario: Unavailable resource
     When the requested resource in the handshake is not available
     Then the server must abort the handshake

  @4_2_2_SendingHandshakeResponse_4 @must
  Scenario: Subprotocol
     When the server is ready to use a subprotocol
     Then it must be a single subprotocol value
      And the subprotocol must be selected from one of the protocols sent by the client

  @4_2_2_SendingHandshakeResponse_4 @must
  Scenario: No subprotocol
     When the server is not ready to use a subprotocol
     Then the server must not send a "Sec-WebSocket-Protocol" field

  @4_2_2_SendingHandshakeResponse_4 @must
  Scenario: Use an extension
     When the server is ready to use an extension
     Then the extensions must be selected from the extension sent by the client

  @4_2_2_SendingHandshakeResponse_4 @must
  Scenario: Not using an extension
     When the server is not ready to use an extension
     Then the server must not send a "Sec-WebSocket-Extensions" field

  @4_2_2_SendingHandshakeResponse_5_1 @must
  Scenario: Accepting the incoming connection, status code
     When the server chooses to accept the incoming connection
     Then the HTTP status code must be 101 Switching Protocols

  @4_2_2_SendingHandshakeResponse_5_2 @must
  Scenario: Accepting the incoming connection, Upgrade header field
     When the server chooses to accept the incoming connection
     Then the "Upgrade" header field must be present with value "websocket"

  @4_2_2_SendingHandshakeResponse_5_3 @must
  Scenario: Accepting the incoming connection, Connection header field
     When the server chooses to accept the incoming connection
     Then the "Connection" header field must be present with value "Upgrade"

  @4_2_2_SendingHandshakeResponse_5_4 @must
  Scenario: Accepting the incoming connection, Sec-WebSocket-Key header field
     When the server chooses to accept the incoming connection
     Then the "Sec-WebSocket-Accept" field must be present
      And its value must the SHA-1 has of the key concatenated with the predefined GUID string

  @4_2_2_SendingHandshakeResponse_5_5 @must
  Scenario: Accepting the incoming connection, subprotocol
     When the server chooses to accept the incoming connection
     Then the "Sec-WebSocket-Protocol" header field may be present

  @4_2_2_SendingHandshakeResponse_5_6 @must
  Scenario: Accepting the incoming connection, extensions
     When the server chooses to accept the incoming connection
     Then the "Sec-WebSocket-Extensions" header field may be present

  @4_2_2_P1 @must
  Scenario: Open state
     When the server successfully completes the handshake
     Then the server considers the connection to be established and in the OPEN state
