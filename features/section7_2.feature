@section7 @section7_2
Feature: Section 7.2: Abnormal closures

  @7_2_1-1 @client @must
  Scenario: Client initiated close on fail
     When the client is requested to fail the connection
     Then it must fail the connection according to section 7.1.7

  @7_2_1-2 @client @must
  Scenario: Underlying connection is lost
     When the underlying connection is unexpectedly lost
     Then the client must failt the WebSocket connection

  @7_2_1-3 @client @should
  Scenario: Abnormal client initiated closure
     When normal operations apply
     Then the client should not close the connection

  @7_2_2 @server @must
  Scenario: Server aborts the WebSocket connection
     When the server is required or recommended to abort the WebSocket connection during the opening handshake
     Then it must simply close the WebSocket connection

  @7_2_3-1 @client @should
  Scenario: Client backoff
     When the client reconnects after abnormal closure
     Then it should use some form of backoff

  @7_2_3-2 @client @should
  Scenario: First client reconnect
     When the client reconnects the first time after abnormal closure
     Then it should delay the reconnection attempt a random amount of time

  @7_2_3-3 @client @may
  Scenario: Delay parameters
     When the client library chooses a random delay
     Then the interval 0 to 5 seconds is reasonable
      And the client may choose another different interval

   @7_2_3-4 @client @should
   Scenario: Subsequent reconnection attempts
     When the first reconnect attempts fail
     Then the subsequent attempts should be delayed by increasingly longer amounts of time
