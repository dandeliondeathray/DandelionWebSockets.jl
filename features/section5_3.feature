@section5 @section5_3 @client
Feature: Section 5.3: Client to server masking
  Frames sent from the client to the server is always masked.

  @5_3-1 @must
  Scenario: The mask bit is set for masked frames
     When a frame is masked
     Then it must have the mask bit set to 1

  @5_3-2-1 @must
  Scenario: Fresh masking key
     When a frame is masked
     Then the client must choose a fresh mask key

  @5_3-2-2 @must
  Scenario: Masking uses strong source of entropy
     When a frame is masked
     Then the mask key must be derived from a strong source of entropy

  @5_3-3 @must
  Scenario: Mask operation
     When octet at index i is masked or unmasked
     Then is is XOR'ed with the mask at index i MOD 4
