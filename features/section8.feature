@section8 @section8_1
Feature: Error handling

  @8_1 @client @server @must
  Scenario: Errors in UTF-8 encoded data
     Given a byte-stream that is invalid UTF-8
      When an endpoint is to intepret that as UTF-8
      Then it must fail the WebSocket connection
