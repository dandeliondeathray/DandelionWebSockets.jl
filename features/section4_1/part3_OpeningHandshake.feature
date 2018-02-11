@section4 @section4_1 @client
Feature: Section 4.1: Opening handshake
  The opening handshake details the initial HTTP handshake after the connection
  has been opened.

  @4_1_P4 @must
  Scenario: WebSocket opening handshake
     When the client has established a connection
     Then the client must send an opening handshake to the server

  @4_1_OpeningHandshake_1 @must
  Scenario: Opening handshake is a valid HTTP request
     When the client sends an opening handshake
     Then the handshake must be a valid HTTP request

  @4_1_OpeningHandshake_2 @must
  Scenario: Opening handshake is an HTTP GET
     When the client sends an opening handshake
     Then the HTTP method must be a GET
      And the HTTP version must be at least 1.1

  @4_1_OpeningHandshake_3 @must
  Scenario: Opening handshake resource name
     When the client sends an opening handshake
     Then the Request-URI part of the request must match the resource name or be an absolute URI matching the resource name

  @4_1_OpeningHandshake_4 @must
  Scenario: Opening handshake Host header field
     When the client sends an opening handshake
     Then the request must contain a "Host" header field

  @4_1_OpeningHandshake_5 @must
  Scenario: Opening handshake Upgrade header field
     When the client sends an opening handshake
     Then the request must contain a "Upgrade" header field
      And it must include the "websocket" keyword

  @4_1_OpeningHandshake_6 @must
  Scenario: Opening handshake Connection header field
     When the client sends an opening handshake
     Then the request must contain a "Connection" header field
      And it must include the "Upgrade" token

  @4_1_OpeningHandshake_7-1 @must
  Scenario: Opening handshake Sec-WebSocket-Key header field
     When the client sends an opening handshake
     Then the request must contain a "Sec-WebSocket-Key" header field

  @4_1_OpeningHandshake_7-2 @must
  Scenario: Opening handshake Sec-WebSocket-Key header field is randomly chosen
     When the client sends an opening handshake
     Then the "Sec-WebSocket-Key" header field must be a randomly selected nonce

  @4_1_OpeningHandshake_8 @must @inapplicable
  Scenario: Opening handshake Origin header field for browser clients
    Given that the client is a browser client
     When the client sends an opening handshake
     Then the request must contain a "Origin" header field

  @4_1_OpeningHandshake_8 @may @inapplicable
  Scenario: Opening handshake Origin header field for non-browser clients
    Given that the client is not a browser client
     When the client sends an opening handshake
     Then the request may contain a "Origin" header field

  @4_1_OpeningHandshake_9 @must
  Scenario: Opening handshake Sec-WebSocket-Version
     When the client sends an opening handshake
     Then the request may contain a "Sec-WebSocket-Version" header field
      And its value must be "13"

  @4_1_OpeningHandshake_10 @may
  Scenario: Opening handshake Sec-WebSocket-Protocol
     When the client sends an opening handshake
     Then the request may contain a "Sec-WebSocket-Protocol" header field

  @4_1_OpeningHandshake_11 @may
  Scenario: Opening handshake Sec-WebSocket-Extensions
     When the client sends an opening handshake
     Then the request may contain a "Sec-WebSocket-Extensions" header field

  @4_1_OpeningHandshake_12 @may @inapplicable
  Scenario: Opening handshake other fields
     When the client sends an opening handshake
     Then the request may contain other fields
