@section3 @client @server
Feature: WebSocket URIs

  Scenario Outline: Schemas
    Given a WebSocket URI <schema>://example.org:1234/examplepath?foo=bar
     When the URI is parsed
     Then host is example.org
      And port is 1234
      And path is examplepath
      And the URI is considered <secure>
      And query string has key foo with value bar

    Examples:
      | schema | secure     |
      | ws     | not secure |
      | WS     | not secure |
      | wss    | secure     |
      | WSS    | secure     |

  Scenario Outline: Default port
    Given a WebSocket URI with <schema>://example.org
     When the URI is parsed
     Then the port is <port>

    Examples:
      | schema | port |
      | ws     | 80   |
      | wss    | 443  |

  Scenario: Fragments are invalid
    Given a WebSocket URI ws://example.org/path\#fragment
     When the URI is parsed
     Then it is invalid

  Scenario: Escaping the \# character is valid
    Given a WebSocket URI ws://example.org/some%23path
     When the URI is parsed
     Then it is invalid
