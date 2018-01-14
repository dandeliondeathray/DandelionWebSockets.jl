@section5 @section5_2 @must
Feature: Framing details
  Data is transmitted between client and server using a sequence of frames.

  @5_2-1 @client @server
  Scenario: FIN bit
     When a message is a single frame
     Then the FIN bit is set on the first frame

  @5_2-2 @client @server
  Scenario: Reserved bits RSV1, RSV2, RSV3, no extension
    Given that no extensions have been negotiated
     When RSV1, RSV2, or RSV3 is non-zero
     Then the endpoint must fail the WebSocket connection

  @5_2-3 @client @server
  Scenario Outline: Opcodes
     When a frame with opcode <opcode> is received
     Then it is known to be a <type> frame
     Examples:
     | opcode | type         |
     | 0x0    | continuation |
     | 0x1    | text         |
     | 0x2    | binary       |
     | 0x8    | close        |
     | 0x9    | ping         |
     | 0xA    | pong         |

  @5_2-4 @client @server
  Scenario Outline: Reserved frames
     When the opcode is in the range <range>
     Then it is a reserved <type> frame
     Examples:
     | range   | type        |
     | 0x3-0x7 | non-control |
     | 0xB-0xF | control     |

  @5_2-5 @client @server
  Scenario Outline: Mask bit
     When the mask bit is <value>
     Then the frame is <ismasked>
     Examples:
     | value | ismasked   |
     | 0     | not masked |
     | 1     | masked     |

  @5_2-6 @client @server
  Scenario: Payload length, 0-125 bytes
     When the payload length field is in the range 0-125 bytes, inclusive
     Then that is the payload length

  @5_2-7 @client @server
  Scenario: Payload length, 126 bytes
     When the payload length field is exactly 126 bytes
     Then the payload length is the following 2 bytes interpreted as a 16-bit integer in network byte order

  @5_2-8 @client @server
  Scenario: Payload length, 127 bytes
     When the payload length field is exactly 127 bytes
     Then the payload length is the following 4 bytes interpreted as a 64-bit integer in network byte order
      And the most significant bit must be zero

  @5_2-9 @client @server
  Scenario: Payload length, mininmal encoding
     When the payload length is encoded
     Then the minimal number of bytes must be used to encode it

  @5_2-10 @client @server
  Scenario: Extension data plus Application data
     When the payload length is encoded
     Then the payload length is the length of the Extension data plus the length of the Application data

  @5_2-11 @client @server
  Scenario: Payload data is Extension data and Application data
     When a frame is encoded or decoded
     Then the payload data is the Extension data concatenated with the Application data

  @5_2-12 @client @server
  Scenario: Extension data with no extensions
     When no extensions have been negotiated
     Then the Extension data is 0 bytes long

  @5_2-13 @client @server @inapplicable
  Scenario: Extensions must specify how extension data is calculated
     When an extension is defined
     Then it must define how the Extension data length is calculated
      And how the extension use is negotiated during the opening handshake
