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
# Chapter 3.3: Date/Time Formats
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
