@section5 @section5_8 @client @server @must
Feature: Extensibility
  The WebSocket protocol allows extensions, which add to the capabilities of the
  base protocol.

  Scenario: Extensions are negotiated during handshake
     When an extension is to be used
     Then it must be negotiated during the handshake
