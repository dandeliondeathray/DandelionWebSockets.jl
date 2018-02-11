@section10
Feature: Section 10: Security considerations

  @10_2-1 @section10_2 @server @should
  Scenario: Origin considerations
    Given that the server is intended to process input only from certain sites
     Then the server should verify that the "Origin" field is as expected

  @10_2-2 @section10_2 @server @should
  Scenario: Unacceptable Origin
     When the server finds an "Origin" header field with an Unacceptable value
     Then it should response to the WebSocket handshake with status code 403 Forbidden

  @10_3-1 @section10_3 @client @must
  Scenario: Client must choose a new masking key for each frame
     When a client creates a new frame
     Then it must use a new masking key

  @10_3-2 @section10_3 @client @must
  Scenario: Payload should not be modifiable during transmission
     When a client is transmitting a message
     Then the payload must not be modifiable by the user application

  @10_4-1 @section10_4 @client @server @must
  Scenario: Protection against exceeding limits
    Given that a implementation or platform has specific limitations regarding frame or message size
     Then the software must protect itself against exceeding those limits

  @10_4-2 @section10_4 @client @server @should
  Scenario: Limits should be imposed
    Given an implementation with limitations
     Then it should impose a limit on frame size
      And the total message size

  @10_7-1 @section10_7 @client @server @must
  Scenario: Incoming data must be validated
     When an endpoint receives data
     Then it must always validate that data

  @10_7-2 @section10_7 @client @server @may
  Scenario: Endpoints may drop the TCP connection after invalid data
     When an endpoint receives invalid data or data that violates some criteria
     Then it may drop the TCP connection

  @10_7-3 @section10_7 @client @server @should
  Scenario: Invalid data after a successful handshake
     When an endpoint receives invalid data after a successful handshake
     Then it should send a Close frame with an appropriate status code before closing the WebSocket connection

  @10_7-4 @section10_7 @client @server @should
  Scenario: Invalid data during handshake
     When invalid data is received during the WebSocket handshake
     Then the server should return an appropriate HTTP status code
