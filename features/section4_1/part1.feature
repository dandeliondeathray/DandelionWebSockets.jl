@section4 @section4_1 @client
Feature: Section 4.1: Connection
  The opening handshake details how the client opens the connection.

  @4_1_P1
  Scenario: Initial connection state
     When a connection is initially created
     Then it is in state CONNECTING

  @4_1_P2 @may @inapplicable
  Scenario: Offload connection management
     When a client is running in a controlled environment
     Then it may offload connection management to another agent
