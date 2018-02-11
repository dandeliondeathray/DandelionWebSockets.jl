@section5 @section5_1
Feature: Section 5.1: Framing overview
  Data is transmitted between client and server using a sequence of frames.

  @5_1-1 @must @client
  Scenario: Client masks frames
     When a client sends a frame to the server
     Then it must be masked

  @5_1-2 @must @server
  Scenario: Server closes connection on unmasked frames
     When the server receives an unmasked frame from a client
     Then the server must close the connection

  @5_1-3 @may @server
  Scenario: Server closes connection on unmasked frames, status code
     When the server receives an unmasked frame from a client
     Then the server may send a Close frame with status code 1002 Protocol Error

  @5_1-4 @must @server
  Scenario: A server does not mask frames
     When the server sends a frame to the client
     Then it must not be masked

  @5_1-5 @must @client
  Scenario: Client closes connection on masked frame
     When the client detects a masked frame sent from the server
     Then the client must close the connection

  @5_1-6 @may @client
  Scenario: Client closes connection on masked frame, status code
     When the client detects a masked frame sent from the server
     Then the client may send a Close frame with status code 1002
