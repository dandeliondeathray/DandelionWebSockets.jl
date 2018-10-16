@wip
Feature: Chapter 3.4: Character Sets

    @chapter3.4_1
    Scenario: A MIME charset definition must be fully specified
         When a definition is associated with a MIME character set
         Then the charset definition must be fully specified

    @chapter3.4_2
    Scenario: Predefined tokens
         When the character set token has a predefined valua within IANA
         Then the token must represent the IANA Character Set definition

    @chapter3.4_3
    Scenario: Limit use of character sets to IANA
         When an application chooses a character set
         Then the charset should be one specified by IANA

    @chapter3.4_4
    Scenario: Include default charset
         When a sender includes a charset
         Then the sender may choose to include it even when it is ISO-8859-1

    @chapter3.4_5 @inapplicable
    Scenario: Should include default charset
         When a sender knows it will not confuse the recipient
         Then it should include the charset if it is ISO-8859-1

    @chapter3.4_6
    Scenario: Respect a provided charset label
         When a sender provides an explicit charset
         Then the receiver must respect that charset label

    @chapter3.4_7 @inapplicable
    Scenario: Do not guess when explicit
        Given a user agent that has a provision to guess a charset
         When an explicit charset is received
         Then it must use that charset, rather than its own preference
