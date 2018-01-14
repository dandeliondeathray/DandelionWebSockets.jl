@section4 @section4_2 @server @irrelevant
Feature: Connection
  The opening handshake details how the server handles a new connection.

  @4_2_P1 @may @irrelevant
  Scenario: Offload connection management
     When a server handles many connections
     Then it may offload connection management to another agent

  @4_2_1 @must
  Scenario: Invalid handshake from client
     When the client's handshake is invalid
     Then the server must stop process the handshake
      And return an HTTP response with an appropriate status code

  @4_2_1_ReadingHandshake_1 @must
  Scenario: Handshake is an HTTP/1.1 GET request
     When the server receives a handshake
     Then the handshake must be a HTTP GET method
      And the HTTP version must be 1.1 or higher
      And a valid "Request-URI" must be present

  @4_2_1_ReadingHandshake_2 @must
  Scenario: Handshake has a Host header field
     When the server receives a handshake
     Then the handshake must contain the "Host" header field

  @4_2_1_ReadingHandshake_3 @must
  Scenario: Handshake has a Upgrade header field
     When the server receives a handshake
     Then the handshake must contain the "Upgrade" header field
      And it must contain the value "websocket"

  @4_2_1_ReadingHandshake_4 @must
   Scenario: Handshake has a Connection header field
      When the server receives a handshake
      Then the handshake must contain the "Connection" header field
       And it must contain the "Upgrade" token

  @4_2_1_ReadingHandshake_5 @must
  Scenario: Handshake has a Sec-WebSocket-Key header field
     When the server receives a handshake
     Then the handshake must contain the "Sec-WebSocket-Key" header field
      And it must be a base64-encoded value that, when decoded, is 16 bytes

  @4_2_1_ReadingHandshake_6 @must
  Scenario: Handshake has a Sec-WebSocket-Version header field
     When the server receives a handshake
     Then the handshake must contain the "Sec-WebSocket-Version" header field
      And it must have the value "13"

  @4_2_1_ReadingHandshake_7 @must
  Scenario: Handshake may have a Origin header field
     When the server receives a handshake
     Then the handshake may contain the "Origin" header field

  @4_2_1_ReadingHandshake_8 @must
  Scenario: Handshake may have a Sec-WebSocket-Protocol header field
     When the server receives a handshake
     Then the handshake may contain the "Sec-WebSocket-Protocol" header field

  @4_2_1_ReadingHandshake_9 @must
  Scenario: Handshake may have a Sec-WebSocket-Extensions header field
     When the server receives a handshake
     Then the handshake may contain the "Sec-WebSocket-Extensions" header field

  @4_2_1_ReadingHandshake_10 @must
  Scenario: Handshake may have other header fields
     When the server receives a handshake
     Then the handshake may contain other header fields
      And those fields must be ignored
