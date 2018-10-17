WebSocketUpgrade identifiable requirements

# Chapter 3.1: HTTP Version
## 3.1-1 MUST
The version of an HTTP message is indicated by an HTTP-Version field
in the first line of the message.

    HTTP-Version   = "HTTP" "/" 1*DIGIT "." 1*DIGIT

## 3.1-2 MUST
Note that the major and minor numbers MUST be treated as separate
integers

## 3.1-3 MAY
Note that the major and minor numbers must be treated as separate
integers and that each MAY be incremented higher than a single digit.

## 3.1-4 MUST
Leading zeros MUST be ignored by recipients.

## 3.1-5 MUST NOT
Leading zeros must be ignored by recipients and MUST NOT be sent.

## 3.1-6 MUST @inapplicable
An application that sends a request or response message that includes
HTTP-Version of "HTTP/1.1" MUST be at least conditionally compliant
with this specification.

## 3.1-7 SHOULD
Applications that are at least conditionally
compliant with this specification SHOULD use an HTTP-Version of
"HTTP/1.1" in their messages...

## 3.1-8 MUST
Applications that are at least conditionally
compliant with this specification should use an HTTP-Version of
"HTTP/1.1" in their messages, and MUST do so for any message that is
not compatible with HTTP/1.0.

## 3.1-9 @inapplicable
The HTTP version of an application is the highest HTTP version for
which the application is at least conditionally compliant.

## 3.1-10 MUST NOT @inapplicable
Since the protocol version indicates the protocol capability of the
sender, a proxy/gateway MUST NOT send a message with a version
indicator which is greater than its actual version.

## 3.1-11 MUST @inapplicable
If a higher version request is received, the proxy/gateway MUST either downgrade
the request version, or respond with an error, or switch to tunnel
behavior.

## 3.1-12 MUST @inapplicable
Due to interoperability problems with HTTP/1.0 proxies discovered
since the publication of RFC 2068[33], caching proxies MUST
upgrade the request to the highest version they support.

## 3.1-13 MAY @inapplicable
Due to interoperability problems with HTTP/1.0 proxies discovered
since the publication of RFC 2068[33], gateways
MAY upgrade the request to the highest version
they support.

## 3.1-14 MUST NOT @inapplicable
Due to interoperability problems with HTTP/1.0 proxies discovered
since the publication of RFC 2068[33], tunnels MUST NOT upgrade the
request to the highest version they support.

## 3.1-15 MUST @inapplicable
The proxy/gateway's response to that request MUST be in
the same major version as the request.

# Chapter 3.2: Uniform Resource Identifiers

## 3.2-1
For definitive information on
URL syntax and semantics, see "Uniform Resource Identifiers (URI):
Generic Syntax and Semantics," RFC 2396 [42] (which replaces RFCs
1738 [4] and RFC 1808 [11]).

## 3.2-2
The HTTP protocol does not place any a priori limit on the length of
a URI.

## 3.2-3 MUST
Servers MUST be able to handle the URI of any resource they serve.

## 3.2-4 SHOULD
Servers must be able to handle the URI of any resource they
serve, and SHOULD be able to handle URIs of unbounded length if they
provide GET-based forms that could generate such URIs.

## 3.2-5
The "http" scheme is used to locate network resources via the HTTP
protocol.

## 3.2-6
This section defines the scheme-specific syntax and
semantics for http URLs.

   http_URL = "http:" "//" host [ ":" port ] [ abs_path [ "?" query ]]

## 3.2-7
If the port is empty or not given, port 80 is assumed.

## 3.2-8
The semantics
are that the identified resource is located at the server listening
for TCP connections on that port of that host, and the Request-URI
for the resource is abs_path (section 5.1.2).

## 3.2-9 SHOULD @inapplicable
The use of IP addresses in URLs SHOULD be avoided whenever possible
(see RFC 1900 [24]).

## 3.2-10
If the abs_path is not present in the URL, it MUST be given as "/" when
used as a Request-URI for a resource (section 5.1.2).

## 3.2-11 @inapplicable
If a proxy receives a host name which is not a fully qualified domain name, it
MAY add its domain to the host name it received.

## 3.2-12 @inapplicable
If a proxy receives a fully qualified domain name, the proxy MUST NOT change
the host name.

## 3.2-13 SHOULD
When comparing two URIs to decide if they match or not, a client
SHOULD use a case-sensitive octet-by-octet comparison of the entire
URIs, with these exceptions:

## 3.2-14 SHOULD
- A port that is empty or not given is equivalent to the default
port for that URI-reference;

## 3.2-15
- Comparisons of host names MUST be case-insensitive;

## 3.2-16
- Comparisons of scheme names MUST be case-insensitive;

## 3.2-17
- An empty abs_path is equivalent to an abs_path of "/".

## 3.2-18
Characters other than those in the "reserved" and "unsafe" sets (see
RFC 2396 [42]) are equivalent to their ""%" HEX HEX" encoding.

For example, the following three URIs are equivalent:

    http://abc.com:80/~smith/home.html
    http://ABC.com/%7Esmith/home.html
    http://ABC.com:/%7esmith/home.html

# Chapter 3.3: Date/Time Formats
HTTP applications have historically allowed three different formats
for the representation of date/time stamps:

    Sun, 06 Nov 1994 08:49:37 GMT  ; RFC 822, updated by RFC 1123
    Sunday, 06-Nov-94 08:49:37 GMT ; RFC 850, obsoleted by RFC 1036
    Sun Nov  6 08:49:37 1994       ; ANSI C's asctime() format

## 3.3-1
The first format is preferred as an Internet standard and represents
a fixed-length subset of that defined by RFC 1123 [8] (an update to
RFC 822 [9]).

## 3.3-2 MUST
HTTP/1.1 clients and servers that parse the date value MUST accept
all three formats (for compatibility with HTTP/1.0)...

## 3.3-3 MUST
HTTP/1.1 clients and servers that parse the date value must accept
all three formats (for compatibility with HTTP/1.0), though they MUST
only generate the RFC 1123 format for representing HTTP-date values
in header fields. See section 19.3 for further information.

## 3.3-4 MUST
All HTTP date/time stamps MUST be represented in Greenwich Mean Time
(GMT), without exception. For the purposes of HTTP, GMT is exactly
equal to UTC (Coordinated Universal Time).

## 3.3-5 MUST
This is indicated in the
first two formats by the inclusion of "GMT" as the three-letter
abbreviation for time zone, and MUST be assumed when reading the
asctime format.

## 3.3-6 MUST NOT
HTTP-date is case sensitive and MUST NOT include
additional LWS beyond that specifically included as SP in the
grammar.

## 3.3-7
    HTTP-date    = rfc1123-date | rfc850-date | asctime-date
    rfc1123-date = wkday "," SP date1 SP time SP "GMT"
    rfc850-date  = weekday "," SP date2 SP time SP "GMT"
    asctime-date = wkday SP date3 SP time SP 4DIGIT
    date1        = 2DIGIT SP month SP 4DIGIT
                    ; day month year (e.g., 02 Jun 1982)
    date2        = 2DIGIT "-" month "-" 2DIGIT
                    ; day-month-year (e.g., 02-Jun-82)
    date3        = month SP ( 2DIGIT | ( SP 1DIGIT ))
                    ; month day (e.g., Jun  2)
    time         = 2DIGIT ":" 2DIGIT ":" 2DIGIT
                    ; 00:00:00 - 23:59:59
    wkday        = "Mon" | "Tue" | "Wed"
                | "Thu" | "Fri" | "Sat" | "Sun"
    weekday      = "Monday" | "Tuesday" | "Wednesday"
                | "Thursday" | "Friday" | "Saturday" | "Sunday"
    month        = "Jan" | "Feb" | "Mar" | "Apr"
                | "May" | "Jun" | "Jul" | "Aug"
                | "Sep" | "Oct" | "Nov" | "Dec"

## 3.3-8
    Note: HTTP requirements for the date/time stamp format apply only
    to their usage within the protocol stream. Clients and servers are
    not required to use these formats for user presentation, request
    logging, etc.

## 3.3-9
Some HTTP header fields allow a time value to be specified as an
integer number of seconds, represented in decimal, after the time
that the message was received.

    delta-seconds  = 1*DIGIT

# Chapter 3.4: Character Sets
# Chapter 3.8: Product Tokens
# Chapter 4.1: Message Types
# Chapter 4.2: Message Headers
# Chapter 4.4: Message Length
# Chapter 4.5: General Header Fields
# Chapter 5.1: Request-Line
# Chapter 5.2: The Resource Identified by a Request
# Chapter 5.3: Request Header Fields
# Chapter 6.1: Status-Line
# Chapter 6.2: Response Header Fields
# Chapter 10.1: Informational 1xx
# Chapter 14.10: Connection
# Chapter 14.18: Date
# Chapter 14.23: Host
# Chapter 14.38: Server
# Chapter 14.42: Upgrade
# Chapter 14.43: User-Agent
# Chapter 15.3: DNS Spoofing
