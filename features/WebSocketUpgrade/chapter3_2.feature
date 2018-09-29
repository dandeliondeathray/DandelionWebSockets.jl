@wip
Feature: Chapter 3.2: Uniform Resource Identifiers

    @chapter3.2_1 @inapplicable
    Scenario: Server must be able to handle the URI for any resource they serve
        Given that the server serves a given URI
         Then the server must be able to handle that URI
    
    @chapter3.2_2 @inapplicable
    Scenario: Server should be able to conditionally handle URIs of unbounded length
        Given that the server serves a resource that generates a URI of unbounded length
         Then it should be able to handle a URI of unbounded length
        
    @chapter3.2_3 @inapplicable
    Scenario: Too long URIs
         When a URI is encountered that is longer than the server can handle
         Then the server should respond with 414 (Request-URI Too Long)
    
    @chapter3.2_4
    Scenario: Port 80 is the default
         When the port of a URI is empty or not given
         Then it defaults to port 80
    
    @chapter3.2_5 @inapplicable
    Scenario: Avoid IP addresses
         When a URL is constructed
         Then IP addresses should be avoided when possible
    
    @chapter3.2_6
    Scenario: Missing abs_path must be /
         When the abs_path is missing in an HTTP URL
         Then it must be given as "/" when used as a Request-URI
    
    @chapter3.2_7 @inapplicable
    Scenario: A proxy may add its domain to a non-FQDN
         When a proxy receives a host name which is not a FQDN
         Then it may add its domain to the host name it received

    @chapter3.2_8 @inapplicable
    Scenario: A proxy may not add its domain to a FQDN
         When a proxy receives a host name which is a FQDN
         Then it must not change the host name

    @chapter3.2_9
    Scenario Outline: Comparing two URIs is case-sensitive with exceptions
         When comparing two URIs
         Then a client should use a case-sensitive octet-by-octet comparison with exception <exception>

        Examples:
            | exception                                                                           |
            | a part that is empty or not given should be the default port for that URI-reference |
            | comparisons of host names must be case-insensitive                                  |
            | comparisons of scheme names must be case-insensitive                                |
            | an empty abs_path is equivalent to an abs_path of "/"                               |

    @chapter3.2_10
    Scenario Outline: Unsafe/reserved characters are equivalent to their hex encoding
         Given URIs <URI1> and <URI2>
          When comparing URI1 and URI2
          Then they are <comparison>
        
        Examples:
            | URI1                               | URI2                               | comparison |
            | http://abc.com:80/~smith/home.html | http://ABC.com/%7Esmith/home.html  | equal      |
            | http://abc.com:80/~smith/home.html | http://ABC.com:/%7esmith/home.html | equal      |
            | http://ABC.com/%7Esmith/home.html  | http://ABC.com:/%7esmith/home.html | equal      |
