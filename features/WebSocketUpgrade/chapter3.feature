@wip
Feature: Chapter 3: Protocol Parameters

    @chapter3.1_1 @must
    Scenario: HTTP Version major and minor are separate numbers
        Given the HTTP version "HTTP/2.4"
         Then the major version is the integer 2
          And the minor version is the integer 4
    
    @chapter3.1_2 @may
    Scenario: HTTP Version numbers may be more than a single digit
        Given the HTTP version "HTTP/10.11"
         Then the major version is the integer 10
          And the minor version is the integer 11

    @chapter3.1_3 @may
    Scenario Outline: HTTP Version comparison
        Given the HTTP versions <Version1> and <Version2>
         When they are compared
         Then the <Version1> is <Order> <Version2>
    
        Examples:
            | Version1  | Order      | Version2  |
            | HTTP/1.0  | equal to   | HTTP/1.0  |
            | HTTP/1.0  | lower than | HTTP/1.1  |
            | HTTP/2.4  | lower than | HTTP/2.13 |
            | HTTP/2.13 | lower than | HTTP/12.3 |

    @chapter3.1_4 @must
    Scenario: HTTP Version leading zeros must be ignored
        Given the HTTP Version "HTTP/01.01"
         Then the major version is 1
          And the minor version is 1
    
    @chapter3.1_5 @must
    Scenario: HTTP Version must not be sent with leading zeros
        Given any request
         When the request is sent
         Then it must not have leading zeros in the HTTP version

    @chapter3.1_6 @must @inapplicable
    Scenario: Applications for HTTP/1.1 must be at least conditionally compliant
        Given that this client uses version HTTP/1.1
         Then it must be a least conditionally compliant with the specification

    @chapter3.1_7 @should @inapplicable
    Scenario: Applications that are at least conditionally compliant should use HTTP/1.1
        Given that an application is conditionally compliant
         Then it should use version HTTP/1.1
    
    @chapter3.1_8 @must @inapplicable
    Scenario: Applications must use HTTP/1.1 when incompatible with HTTP/1.0
        Given that a message is incompatible with HTTP/1.0
         When it is sent from an application
         Then it must be version HTTP/1.1
    
    @chapter3.1_9 @inapplicable
    Scenario: The version is the highest one for which the applications is at least conditionally compliant
        Given that HTTP/1.1 is the highest version for which the application is at least conditionally compliant
         Then it should use version HTTP/1.1

    @chapter3.1_10 @inapplicable
    Scenario: A proxy/gateway may not send a message with a higher version
        Given that the proxy/gateway has some version
         When a message is received with a higher version
         Then the proxy/gateway must downgrade, response with an error, or switch to tunnel behaviour

    @chapter3.1_11 @inapplicable
    Scenario: A caching proxy must upgrade the request to the highest version they support
        Given that a caching proxy has some version
         When a message is receive with a lower version
         Then the caching proxy must upgrade to its highest version

    @chapter3.1_12 @inapplicable
    Scenario: A gateway may upgrade the request to the highest version they support
        Given that a gateway has some version
         When a message is receive with a lower version
         Then the gateway may upgrade to its highest version

    @chapter3.1_13 @inapplicable
    Scenario: A tunnel may not upgrade the request to the highest version they support
        Given that a tunnel has some version
         When a message is receive with a lower version
         Then the tunnel may not upgrade to its highest version
