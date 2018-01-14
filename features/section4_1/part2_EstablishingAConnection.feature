@section4 @section4_1 @client
Feature: Establishing a connection
  Establishing a connection details the requirement on how the TCP connection is
  opened.

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
