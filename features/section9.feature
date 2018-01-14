@section9
Feature: Extensions

  @9_1-1 @section9_1 @client @server @must
  Scenario: Invalid extensions handshake data
     When an endpoint receives an invalid extensions request, according to section 9.1
     Then the endpoint must immediately fail the WebSocket connection

  @9_1-2 @section9_1 @client @server @must
  Scenario: Extensions may be split across multiple headers
     When the "Sec-WebSocket-Extensions" header field occurs multiple times
     Then the endpoint must combine the extension lists

  @9_1-3 @section9_1 @client @server @may
  Scenario: Extensions may split the extensions across multiple headers
     When an endpoint sends extension in the handshake
     Then it may split the extensions across more than one "Sec-WebSocket-Extensions" header field

  @9_1-4 @section9_1 @client @server @must
  Scenario: Extension tokens must be registered
     When an extension token is used
     Then it must be a registered token according to section 11.4

  @9_1-5 @section9_1 @client @server @must
  Scenario: Extension parameters must be defined
     When an extension is used with parameters
     Then the parameters must be defined for that extension

  @9_1-6 @section9_1 @client @must
  Scenario: Clients offer extensions
     When a client offers an extension in the handshake
     Then it must not use that extension unless the server indicates that it can

  @9_1-7 @section9_1 @client @server @may
  Scenario: Extensions with interactions
    Given that the client lists extensions in the handshake
     Then there may be interactions between the extensions

  @9_1-8 @section9_1 @client @server @must
  Scenario: Extension list order
    Given that no interactions are defined between extensions listed by the client
     When the client lists the extensions in the handshake
     Then the first extension listed is the most preferable

  @9_1-9 @section9_1 @client @server @must
  Scenario: Extensions that modify data
    Given that the extensions modify the data or framing of messages
     When the server's handshake response contains multiple extensions
     Then the data is modified in the order that the extensions are listed in the servers response

  @9_2 @section9_2 @client @server @may
  Scenario: Implementations may use separately defined extensions
    Given that the specification does not define any extensions
     Then the implementation may use separately defined extensions
