@section5 @section5_4 @client @server
Feature: Section 5.4: Fragmentation
  Messages are sent in fragments, to avoid having to buffer entire messages.

  @5_4-1 @must
  Scenario: Unfragmented message
     When an unfragmented message is processed
     Then the message is a single frame with the FIN bit set and an opcode other than 0

  @5_4-2 @must
  Scenario: Fragmented messages
     When a fragmented message is processed
     Then the message consists of a single frame with the FIN bit cleared an opcode other than 0
      And zero or more frames with the FIN bit clear and the opcode set to 0
      And terminated by a single frame with the FIN bit set and an opcode of 0

  @5_4-3 @must
  Scenario: Control frames in a fragment sequence
     When a fragmented message is processed
     Then a control frame may be injected anywhere into the sequence of fragments

  @5_4-4 @must
  Scenario: Control frames are not fragmented
     When a control frame is processed
     Then it must not be fragmented

  @5_4-5 @must
  Scenario: Fragment order
     When a fragmented message is sent
     Then it must be delivered to the recipient in the order it was sent

  @5_4-6 @must
  Scenario: No message interleaving, if no extension is negotiated
    Given that no extension has been negotiated
     When fragment sequences are being sent
     Then fragments from one message may not be interleaved with another

  @5_4-7 @must
  Scenario: Handling control frames in fragment sequences
     When a fragmented message is being received
     Then an endpoint must be capable of handling a control frame injected into the fragment sequence

  @5_4-8 @may
  Scenario: Fragment size for non control messages
     When a sender is creating non-control fragments
     Then they may be of any size

  @5_4-9 @must
  Scenario: Fragmented and unfragmented messages
     When an endpoint handles messages
     Then it must be able to handle both fragmented and unfragmented messages

  @5_4-10 @must @inapplicable
  Scenario: Intermediary with control frames
     When an intermediary is processing fragments
     Then it must not change the fragmentation of a control frame

  @5_4-11 @must @inapplicable
  Scenario: Intermediary with reserved bits
    Given that an intermediary does not know the meaning of reserved bits
     When a message with reserved bits set is processed
     Then it must not change the fragmentation of the message

  @5_4-12 @must @inapplicable
  Scenario: Intermediary with extensions
    Given that extensions have been negotiated
      And that the intermediary is not aware of the sematics of the extension
     When a message is processed
     Then it must not change the fragmentation of the message
