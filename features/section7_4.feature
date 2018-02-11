@section7 @section7_4
Feature: Section 7.4: Status codes

  @7_4 @client @server @may
  Scenario: Reason for closure
     When closing an established connection
     Then the endpoint may indicate a reason for closure

  @7_4_1-1 @client @server @must
  Scenario Outline: Pre-defined status codes
     When sending a Close frame
     Then the endpoint may use the status code <code> to indicate reason <reason>

     Examples:
     | code | reason                          |
     | 1000 | normal closure                  |
     | 1001 | endpoint is going away          |
     | 1002 | protocol error                  |
     | 1003 | unacceptable data               |
     | 1004 | reserved                        |
     | 1007 | inconsistent data               |
     | 1008 | policy violation                |
     | 1009 | message is too big              |
     | 1010 | no expected extension           |
     | 1011 | server had unexpected condition |

  @7_4_1-2 @client @server @must
  Scenario Outline: Unusable status codes
     When sending a Close frame
     Then the endpoint may not use the status code <code> because it is used to indicate that <reason>

     Examples:
     | code | reason                                    |
     | 1005 | no status code was present in Close frame |
     | 1006 | the connection was closed abnormally      |
     | 1015 | TLS handshake failure                     |

  @7_4_2 @client @server @must
  Scenario Outline: Reserved status code ranges
     Given the reserved status code range <range>
      Then the expected use is <use>

     Examples:
     | range     | use                                             |
     | 0-999     | unused                                          |
     | 1000-2999 | this protocol, future revisions, and extensions |
     | 3000-3999 | registered with IANA for use by software        |
     | 4000-4999 | private use, cannot be registered               |
