@section6 @section6_2
Feature: Receiving data

  @6_2-1 @client @server @must
  Scenario: Incoming data
     When data has been read on the connection
     Then it must be parsed as WebSocket frames

  @6_2-2 @client @server @must
  Scenario: Incoming control frames
     When a control frame is received
     Then it must be handled according to section 5.5

  @6_2-3 @client @server @must
  Scenario: Receiving a data frame
     When a data frame is received
     Then the endpoint must note the type of the data as defined by the opcode

  @6_2-4 @client @server @must
  Scenario: Message has been received, single frame
     When an unfragmented message is received
     Then a WebSocket message has been received
      And the Application data is the data from that frame

  @6_2-5 @client @server @must
  Scenario: Message has been received, multi-frame
     When the last fragment of a fragmented message is received
     Then a WebSocket message has been received
     Then the Application data is the concatenation of all the frame's payloads

  @6_2-6 @client @server @must
  Scenario: Next message
     When the last fragment in a message has been received
      And a new frame is received
     Then the new frame must be considered part of a new message

  @6_2-7 @client @server @must
  Scenario: Extensions may change how messages are read
     When an extension has been negotiated
     Then the extension may change how a message is read

  @6_2-8 @client @server @may
  Scenario: Extensions may modify Application data
     When an extension has been negotiated
     Then it may modify the Application data of frames

  @6_2-9 @server @must
  Scenario: Server must remove masking
     When a server receives a frame from a client
     Then it must remove the masking
