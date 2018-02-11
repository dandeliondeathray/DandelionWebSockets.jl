@section5 @section5_5
Feature: Control frames

  @5_5-1 @client @server @must
  Scenario: Control frame length
     When a control frame is created
     Then the payload length must be less than or equal to 125 bytes

  @5_5-2 @client @server @must
  Scenario: Control frame fragmentation
      When a control frame is created or processed
      Then it must not be fragmented

  @5_5_1-1 @client @server @may
  Scenario: Close frame may contain a body
      When a Close frame is created
      Then it may contain a body

  @5_5_1-2 @client @server @may
  Scenario: Close frame body status code
     Given a payload for the Close frame
      When the Close frame is created
      Then the first two bytes of the body must be a status code in network byte order
       And the rest of the body may be UTF-8 encoded data

  @5_5_1-3 @client @server @may
  Scenario: Close frame body, reason
      When a Close frame with a UTF-8 encoded reason is received
      Then it must not be shown to end users

  @5_5_1-4 @client @server @must
  Scenario: No frames after Close frame
      When the endpoint has sent a Close frame
      Then the application must not send any more data frames

  @5_5_1-5 @client @server @must
  Scenario: Respond to Close frame
     Given that the endpoint has not sent a Close frame
      When it receives a Close frame
      Then it must send a Close frame in response

  @5_5_1-6 @client @server @should
  Scenario: Response time for Close frame
     When the endpoint sends a Close frame in response
     Then it should do so as soon as practical

  @5_5_1-7 @client @server @may
  Scenario: Delay Close frame
     When an endpoint is currently sending a message
     Then it may delay sending a Close frame in response

  @5_5_1-8 @client @server  @must
  Scenario: Endpoint closed
     When an endpoint has sent and received a Close frame
     Then the TCP connection must be closed

  @5_5_1-9 @server @must
  Scenario: Server closes the connection
     When a server has sent and received a Close frame
     Then it must close the TCP connection immediately

  @5_5_1-10 @client @should
  Scenario: Client closes the connection
     When a client has sent and received a Close frame
     Then it should wait for the server to close the connection

  @5_5_1-11 @client @may
  Scenario: Client closes the connection, if reasonable
     When a client has sent and received a Close frame
     Then it may close the connection at any time if it is reasonable

  @5_5_2-1 @client @server @may
  Scenario: Ping frame application data
     When a Ping frame is created
     Then it may include Application data

  @5_5_2-2 @client @server @must
  Scenario: Pong response
     When an endpoint receives a Ping frame
     Then it must send a Pong frame in response, unless a Close frame has been received

  @5_5_2-3 @client @server @should
  Scenario: Pong response time
     When an endpoint receives a Ping frame
     Then it should respond with a Pong frame as soon as is practical

  @5_5_2-4 @client @server @may
  Scenario: Ping frame validity
     When a connection is established
      And it is not closed
     Then an endpoint may sent a Ping frame at any time

  @5_5_3-1 @client @server @must
  Scenario: Pong frame Application data
    Given that an endpoint has received a Ping frame with Application data
     When and endpoint sends a Pong frame in response the ping
     Then the Pong frame must have identical Application data as the Ping frame

  @5_5_3-1 @client @server @may
  Scenario: Pong frame for multiple Ping frames
    Given that an endpoint has received multiple Ping frames without sending a Pong frame
     When it sends a Pong frame
     Then it may elect to only send a Pong frame for the most recent Ping frame

  @5_5_3-1 @client @server @may
  Scenario: Unsolicited Pong frame
     When an endpoint needs to have a unidirectional heartbeat
     Then it may send an unsolicited Pong frame

  @5_5_3-1 @client @server @must
  Scenario: Unsolicited Pong frame response
     When an endpoint receives an unsolicited Pong frame
     Then it is not expected to send a response
