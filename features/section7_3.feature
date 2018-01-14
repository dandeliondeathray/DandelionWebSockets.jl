@section7 @section7_3
Feature: Normal closure of connections

  @7_3-1 @server @may
  Scenario: Servers may close the connection when desired
     When a server desires
     Then it may close the WebSocket connection at any time

  @7_3-2 @client @should
  Scenario: Clients should not close the WebSocket connection arbitrarily
     When a client has no reason to close the connection
     Then it should not close the WebSocket connection arbitrarily
