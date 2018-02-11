@section7 @section7_1
Feature: Section 7.1: Close the WebSocket connection
  The WebSocket connection refers to the entirety of the WebSocket protocol as
  well as the underlying connection. The TCP connection refers only to the
  underlying connection.

  @7_1_1-1 @server @client @should
  Scenario: Closing the underlying TCP connection
     When an endpoint closes the connection
     Then the endpoint should use a method that cleanly closes the TCP connection

  @7_1_1-2 @server @client @should
  Scenario: Discard trailing bytes
     When and endpoint closes the connection
     Then it should discard any trailing bytes that were received

  @7_1_1-3 @server @client @may
  Scenario: Close the connection non-cleanly when necessary
     When an endpoint deems it necessary
     Then it may close the connection by any means necessary

  @7_1_1-4 @server @should
  Scenario: The server should close the TCP connection first
     When a connection is to be closed
     Then the server should close the TCP connection first

  @7_1_1-5 @client @may
  Scenario: The client may close the TCP connection in abnormal circumstances
     When abnormal circumstances occur
     Then the client may close the TCP connection first

  @7_1_1-6 @server @should
  Scenario: Server closes TCP immediately
     When a server is to Close the connection
     Then it should do so immediately

  @7_1_1-7 @client @should
  Scenario: Client should wait for the server to close the TCP connection
     When a client is to Close the connection
     Then it should wait for the server to close the TCP connection

  @7_1_2-1 @server @client @must
  Scenario: Start the Closing handshake
     When an endpoint is to close the WebSocket connection
     Then the endpoint must send a Close control frame

  @7_1_2-2 @server @client @should
  Scenario: Closing the connection
     When an endpoint has both sent and received a Close control frame
     Then it should close the WebSocket connection

  @7_1_3-1 @server @client @must
  Scenario: Closing handshake is started
     When a Close control frame has been sent or received
     Then the WebSocket connection is in the CLOSING state
      And it is said that the "WebSocket Closing Handshake is Started"

  @7_1_4-1 @server @client @must
  Scenario: Underlying connection is closed
     When the underlying TCP connection is closed
     Then the WebSocket connection is in the CLOSED state
      And it is said that the "WebSocket Connection is Closed"

  @7_1_4-2 @server @client @must
  Scenario: Clean close
     When the WebSocket closing handshake was completed before the TCP connection was closed
     Then the WebSocket connection is said to have been closed cleanly

  @7_1_4-3 @server @client @must
  Scenario: Unclean close
     When the WebSocket connection could not be established
     Then it is said that the "WebSocket Connection is Closed"
      And it is not said to have been closed cleanly

  @7_1_5-1 @server @client @must
  Scenario: WebSocket Connection Close Code sent by Close frame
    Given that the WebSocket connection is closed
     When the first Close frame was received with a status code
     Then the "WebSocket Connection Close Code" is the status code of that close frame

  @7_1_5-2 @server @client @must
  Scenario: WebSocket Connection Close Code sent by Close frame with no status code
   Given that the WebSocket connection is closed
     When the first Close frame was received with no status code
     Then the "WebSocket Connection Close Code" is 1005

  @7_1_5-3 @server @client @must
  Scenario: WebSocket Connection Close Code with no Close frame
    Given that the WebSocket connection is closed
     When no Close frame has been received
     Then the "WebSocket Connection Close Code" is 1006

  @7_1_6-1 @server @client @must
  Scenario: WebSocket Connection Close Reason with reason
    Given that the WebSocket connection is closed
     When the first Close frame was received with Application data
     Then the "WebSocket Connection Close Reason" is the string of that data

  @7_1_6-2 @server @client @must
  Scenario: WebSocket Connection Close Reason without reason
    Given that the WebSocket connection is closed
     When the first Close frame was received without Application data
     Then the "WebSocket Connection Close Reason" is the empty string

  @7_1_7-1 @client @must
  Scenario: Clients fail the WebSocket connection
     When the client is to fail the WebSocket connection
     Then it must close the WebSocket connection

  @7_1_7-2 @client @must
  Scenario: Clients fail the WebSocket connection and inform the user
     When the client is to fail the WebSocket connection
     Then it may report the problem to the user

  @7_1_7-3 @server @must
  Scenario: Servers fail the WebSocket connection
     When the server is to fail the WebSocket connection
     Then it must close the WebSocket connection

  @7_1_7-4 @server @must
  Scenario: Servers fail the WebSocket connection and inform the user
     When the server is to fail the WebSocket connection
     Then it should log the problem

  @7_1_7-5 @server @client @should
  Scenario: Connection established before fail
     When the connection has been established prior to requiring the endpoint to fail the connection
     Then then endpoint should send a Close frame with an appropriate status code
      And then close the WebSocket connection

  @7_1_7-6 @server @client @may
  Scenario: Omit the Close frame during fail
    Given the endpoint is to fail the WebSocket connection
     When the endpoint has reason to believe that the other side will not receive the Close frame
     Then it may omit sending the Close frame

  @7_1_7-7 @server @client @must
  Scenario: Processing data after WebSocket connection fail
     When the endpoint is to fail the WebSocket connection
     Then it must not continue to attempt to process data, including sending a Close frame response

  @7_1_7-8 @client @should
  Scenario: Clients should not close the connection during fail
     When a client is to fail the WebSocket connection
     Then the connection should not close the TCP connection
