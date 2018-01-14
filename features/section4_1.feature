@section4 @section4_1 @client
Feature: Opening Handshake
  The opening handshake details how the client opens the connection.

  @4_1_P1
  Scenario: Initial connection state
     When a connection is initially created
     Then it is in state CONNECTING

  @4_1_P2 @may @irrelevant
  Scenario: Offload connection management
     When a client is running in a controlled environment
     Then it may offload connection management to another agent

  @4_1_P3 @must
  Scenario: Establish a WebSocket connection
    Given a set of host, port, resource name, secure flag
      And a list of protocols and extensions
     When the client is to establish a WebSocket connection
     Then it must open a connection
      And send an opening handshake
      And read the server's handshake in response

  @4_1_EstablishConnection_1 @must
  Scenario: Valid WebSocket URI
     When the client is to establish a WebSocket connection
     Then the WebSocket URI must be valid according to section 3

  @4_1_EstablishConnection_1 @must
  Scenario: Invalid WebSocket URI
    Given an invalid WebSocket URI
     When the client is to establish a WebSocket connection
     Then the client must fail the WebSocket connection

  @4_1_EstablishConnection_2 @must
  Scenario: Existing connection
    Given that a there is an connection to a given host
     When the client is to establish a WebSocket connection to the same host
     Then the client must wait for that connection to be established or failed
      And there must be no more than one connection in the CONNECTING state

  @4_1_EstablishConnection_2 @must
  Scenario: Identifying hosts
     When the client cannot determine the IP addresses of remote hosts
     Then the client must assume that each host name refers to a distinct host

  @4_1_EstablishConnection_2 @should @wontimplement
  Scenario: Limit pending connections
     When the client cannot determine the IP addresses of remote hosts
     Then the client should limit the total number of pending connections

  @4_1_EstablishConnection_3 @should
  Scenario: Using a proxy
     When the client is configured to use a proxy
     Then the client should use the proxy to connect to the remote host

  @4_1_EstablishConnection_3 @should
  Scenario: Not using a proxy
     When the client is not configured to use a proxy
     Then a direct connection should be opening to the remote host

  @4_1_EstablishConnection_4 @must
  Scenario: Could not open the connection
     When the connection could not be opened
     Then the client must fail the WebSocket connection

  @4_1_EstablishConnection_5 @must
  Scenario: Using TLS
    Given that the secure flag is true
     When the client is to establish a WebSocket connection
     Then the client MUST perform a TLS handshake before sending data

  @4_1_EstablishConnection_5 @must
  Scenario: TLS connection fails
    Given that the secure flag is true
     When the TLS handshake fails
     Then the client must fail the WebSocket connection

  @4_1_EstablishConnection_5 @must
  Scenario: Server Name Indication extension in TLS
    Given that the secure flag is true
     When the client is to establish a WebSocket connection
     Then the client must use the Server Name Indication extension in the TLS handshake

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

  @4_1_OpeningHandshake_7 @must
  Scenario: Opening handshake Sec-WebSocket-Key header field
     When the client sends an opening handshake
     Then the request must contain a "Sec-WebSocket-Key" header field
      And and its value must be a randomly selected nonce

  @4_1_OpeningHandshake_8 @must @irrelevant
  Scenario: Opening handshake Origin header field for browser clients
    Given that the client is a browser client
     When the client sends an opening handshake
     Then the request must contain a "Origin" header field

  @4_1_OpeningHandshake_8 @may
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

  @4_1_OpeningHandshake_12 @may
  Scenario: Opening handshake other fields
     When the client sends an opening handshake
     Then the request may contain other fields
