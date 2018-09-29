@wip
Feature: Chapter 3.3: Date/Time Formats

    @chapter3.3_1
    Scenario Outline: Accepting date formats
         When receiving a message with date format <format>
         Then the server must accept this format
        
        Examples:
            | format             |
            | RFC 822            |
            | RFC 1123           |
            | RFC 850            |
            | RFC 1036           |
            | ANSI C's asctime() |
    
    @chapter3.3_2
    Scenario: Date/Time: Generate only RFC 1123
         When generating a date format
         Then an application must only generate format RFC 1123

    @chapter3.3_3
    Scenario: Date/Time: Time zone
         When representing a date/time stamp
         Then the representation must be GMT
    
    @chapter3.3_4
    Scenario: Date/Time: Assume GMT when using asctime
         When reading a asctime date/time stamp
         Then the timezone GMT must be assumed
    
    @chapter3.3_5
    Scenario: Date/Time: An HTTP date must not us extra whitespace
         When processing an HTTP-date
         Then extra linear whitespace must not be included beyond the specifically stated spaces

    @chapter3.3_6
    Scenario: Date/Time: Delta seconds
         When processing some HTTP fields
         Then time may be specified as an integer number of seconds, in decimal
          And it implies time after the message was received
