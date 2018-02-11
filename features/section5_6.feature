@section5 @section5_6 @client @server @must
Feature: Section 5.6: Data frames

  @5_6-1
  Scenario: Partial UTF-8 sequences
     When a text message is fragmented
     Then each fragment might include only a partial UTF-8 sequence

  @5_6-2
  Scenario: Message has a complete UTF-8 sequence
     When a complete text message is received
     Then it must be a valid UTF-8 sequence
