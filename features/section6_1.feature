@section6 @section6_1
Feature: Sending data
  Sending a WebSocket message over a connection.

  @6_1-1 @client @server @must
  Scenario: Sending data only on OPEN connections
     When an endpoint is to send a message
     Then the connection must be in the OPEN state

  @6_1-2 @client @server @must
  Scenario: Connection closes when sending data
     When an endpoint is the send a message
      And the connection is no longer in the OPEN state
     Then it must abort the sending of the message

  @6_1-3 @client @server @must
  Scenario: Encapsulating data in a single frame message
     When the message is to be sent as a single frame
     Then the endpoint must encapsulate the data in the payload

  @6_1-4 @client @server @must
  Scenario: Encapsulating the data in a multi-frame message
     When the message cannot be sent as a single frame
     Then the endpoint may encapsulate the data in a sequence of frames

  @6_1-5 @client @server @must
  Scenario: Opcode in the first frame
     When the first frame in a message is created
     Then the opcode must be set to an appropriate value

  @6_1-6 @client @server @must
  Scenario: FIN bit must be set in the last frame
     When a multi-frame message is sent
     Then the last frame must have the FIN bit set

  @6_1-7 @client @must
  Scenario: Masking client frames
     When the client sends a frame
     Then the frame must be masked

  @6_1-8 @client @server @must
  Scenario: Transmitting frames
     When an endpoint has formed frames
     Then those frames must be transmitted over the underlying network connection
