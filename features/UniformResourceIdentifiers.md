Identifiable requirements for Uniform Resource Identifiers.

# Chapter 1.3: Example URI
## 1.3-1
   The following examples illustrate URI that are in common use.

   ftp://ftp.is.co.za/rfc/rfc1808.txt
      -- ftp scheme for File Transfer Protocol services

   gopher://spinaltap.micro.umn.edu/00/Weather/California/Los%20Angeles
      -- gopher scheme for Gopher and Gopher+ Protocol services

   http://www.math.uio.no/faq/compression-faq/part1.html
      -- http scheme for Hypertext Transfer Protocol services

   telnet://melvyl.ucop.edu/
      -- telnet scheme for interactive services via the TELNET Protocol

## 1.3-2
The following examples illustrate URI that are in common use.

    mailto:mduerst@ifi.unizh.ch
        -- mailto scheme for electronic mail addresses

    news:comp.infosystems.www.servers.unix
        -- news scheme for USENET news groups and articles

# Chapter 2.2: Reserved Characters
## 2.2-1
Many URI include components consisting of or delimited by, certain
special characters.  These characters are called "reserved", since
their usage within the URI component is limited to their reserved
purpose.  If the data for a URI component would conflict with the
reserved purpose, then the conflicting data must be escaped before
forming the URI.

    reserved    = ";" | "/" | "?" | ":" | "@" | "&" | "=" | "+" |
                "$" | ","

## 2.2-2
The "reserved" syntax class above refers to those characters that are
allowed within a URI, but which may not be allowed within a
particular component of the generic URI syntax; they are used as
delimiters of the components described in Section 3.

## 2.2-3
Characters in the "reserved" set are not reserved in all contexts.
The set of characters actually reserved within any given URI
component is defined by that component. In general, a character is
reserved if the semantics of the URI changes if the character is
replaced with its escaped US-ASCII encoding.

# Chapter 2.3: Unreserved Characters
## 2.3-1
Data characters that are allowed in a URI but do not have a reserved
purpose are called unreserved.  These include upper and lower case
letters, decimal digits, and a limited set of punctuation marks and
symbols.

    unreserved  = alphanum | mark

    mark        = "-" | "_" | "." | "!" | "~" | "*" | "'" | "(" | ")"

Unreserved characters can be escaped without changing the semantics
of the URI, but this should not be done unless the URI is being used
in a context that does not allow the unescaped character to appear.

# Chapter 2.4: Escape Sequences
## 2.4-1
Data must be escaped if it does not have a representation using an
unreserved character; this includes data that does not correspond to
a printable character of the US-ASCII coded character set, or that
corresponds to any US-ASCII character that is disallowed, as
explained below.

# Chapter 2.4.1: Escaped Encoding
## 2.4.1-1
An escaped octet is encoded as a character triplet, consisting of the
percent character "%" followed by the two hexadecimal digits
representing the octet code. For example, "%20" is the escaped
encoding for the US-ASCII space character.

    escaped     = "%" hex hex
    hex         = digit | "A" | "B" | "C" | "D" | "E" | "F" |
                          "a" | "b" | "c" | "d" | "e" | "f"

# Chapter 2.4.2: When to Escape and Unescape
## 2.4.2-1
A URI is always in an "escaped" form, since escaping or unescaping a
completed URI might change its semantics.  Normally, the only time
escape encodings can safely be made is when the URI is being created
from its component parts; each component may have its own set of
characters that are reserved, so only the mechanism responsible for
generating or interpreting that component can determine whether or
not escaping a character will change its semantics. Likewise, a URI
must be separated into its components before the escaped characters
within those components can be safely decoded.

## 2.4.2-2
In some cases, data that could be represented by an unreserved
character may appear escaped; for example, some of the unreserved
"mark" characters are automatically escaped by some systems.  If the
given URI scheme defines a canonicalization algorithm, then
unreserved characters may be unescaped according to that algorithm.
For example, "%7e" is sometimes used instead of "~" in an http URL
path, but the two are equivalent for an http URL.

## 2.4.2-3
Because the percent "%" character always has the reserved purpose of
being the escape indicator, it must be escaped as "%25" in order to
be used as data within a URI.  Implementers should be careful not to
escape or unescape the same string more than once, since unescaping
an already unescaped string might lead to misinterpreting a percent
data character as another escaped character, or vice versa in the
case of escaping an already escaped string.

# Chapter 2.4.3: Excluded US-ASCII Characters
## 2.4.3-1
The space character is excluded because significant spaces may
disappear and insignificant spaces may be introduced when URI are
transcribed or typeset or subjected to the treatment of word-
processing programs.  Whitespace is also used to delimit URI in many
contexts.

space       = <US-ASCII coded character 20 hexadecimal>

## 2.4.3-2
The angle-bracket "<" and ">" and double-quote (") characters are
excluded because they are often used as the delimiters around URI in
text documents and protocol fields.  The character "#" is excluded
because it is used to delimit a URI from a fragment identifier in URI
references (Section 4). The percent character "%" is excluded because
it is used for the encoding of escaped characters.

delims      = "<" | ">" | "#" | "%" | <">

## 2.4.3-3
Other characters are excluded because gateways and other transport
agents are known to sometimes modify such characters, or they are
used as delimiters.

unwise      = "{" | "}" | "|" | "\" | "^" | "[" | "]" | "`"

Data corresponding to excluded characters must be escaped in order to
be properly represented within a URI.

# Chapter 3: URI Syntactic Components
## 3-1
The URI syntax does not require that the scheme-specific-part have
any general structure or set of semantics which is common among all
URI.  However, a subset of URI do share a common syntax for
representing hierarchical relationships within the namespace.  This
"generic URI" syntax consists of a sequence of four main components:

    <scheme>://<authority><path>?<query>

each of which, except <scheme>, may be absent from a particular URI.
For example, some URI schemes do not allow an <authority> component,
and others do not use a <query> component.

## 3-2
    absoluteURI   = scheme ":" ( hier_part | opaque_part )

URI that are hierarchical in nature use the slash "/" character for
separating hierarchical components.  For some file systems, a "/"
character (used to denote the hierarchical structure of a URI) is the
delimiter used to construct a file name hierarchy, and thus the URI
path will look similar to a file pathname.  This does NOT imply that
the resource is a file or that the URI maps to an actual filesystem
pathname.

    hier_part     = ( net_path | abs_path ) [ "?" query ]

    net_path      = "//" authority [ abs_path ]

    abs_path      = "/"  path_segments

## 3-3
URI that do not make use of the slash "/" character for separating
hierarchical components are considered opaque by the generic URI
parser.

    opaque_part   = uric_no_slash *uric

    uric_no_slash = unreserved | escaped | ";" | "?" | ":" | "@" |
                    "&" | "=" | "+" | "$" | ","

We use the term <path> to refer to both the <abs_path> and
<opaque_part> constructs, since they are mutually exclusive for any
given URI and can be parsed as a single component.

# Chapter 3.1: Scheme Component
## 3.1-1
Scheme names consist of a sequence of characters beginning with a
lower case letter and followed by any combination of lower case
letters, digits, plus ("+"), period ("."), or hyphen ("-").  For
resiliency, programs interpreting URI should treat upper case letters
as equivalent to lower case in scheme names (e.g., allow "HTTP" as
well as "http").

    scheme        = alpha *( alpha | digit | "+" | "-" | "." )

## 3.1-2
Relative URI references are distinguished from absolute URI in that
they do not begin with a scheme name.  Instead, the scheme is
inherited from the base URI, as described in Section 5.2.

# Chapter 3.2: Authority Component
## 3.2-1
Many URI schemes include a top hierarchical element for a naming
authority, such that the namespace defined by the remainder of the
URI is governed by that authority.  This authority component is
typically defined by an Internet-based server or a scheme-specific
registry of naming authorities.

    authority     = server | reg_name

The authority component is preceded by a double slash "//" and is
terminated by the next slash "/", question-mark "?", or by the end of
the URI.  Within the authority component, the characters ";", ":",
"@", "?", and "/" are reserved.

## 3.2-2
An authority component is not required for a URI scheme to make use
of relative references.  A base URI without an authority component
implies that any relative reference will also be without an authority
component.

# Chapter 3.2.1: Registry-baed Naming Authority
## 3.2.1-1
The structure of a registry-based naming authority is specific to the
URI scheme, but constrained to the allowed characters for an
authority component.

    reg_name      = 1*( unreserved | escaped | "$" | "," |
                        ";" | ":" | "@" | "&" | "=" | "+" )

# Chapter 3.2.2: Server-baesd Naming Authority
## 3.2.2-1
URL schemes that involve the direct use of an IP-based protocol to a
specified server on the Internet use a common syntax for the server
component of the URI's scheme-specific data:

    <userinfo>@<host>:<port>

where <userinfo> may consist of a user name and, optionally, scheme-
specific information about how to gain authorization to access the
server.  The parts "<userinfo>@" and ":<port>" may be omitted.

    server        = [ [ userinfo "@" ] hostport ]

The user information, if present, is followed by a commercial at-sign
"@".

    userinfo      = *( unreserved | escaped |
                        ";" | ":" | "&" | "=" | "+" | "$" | "," )

## 3.2.2-2
Some URL schemes use the format "user:password" in the userinfo
field. This practice is NOT RECOMMENDED, because the passing of
authentication information in clear text (such as URI) has proven to
be a security risk in almost every case where it has been used.

## 3.2.2-3
The host is a domain name of a network host, or its IPv4 address as a
set of four decimal digit groups separated by ".".  Literal IPv6
addresses are not supported.

    hostport      = host [ ":" port ]
    host          = hostname | IPv4address
    hostname      = *( domainlabel "." ) toplabel [ "." ]
    domainlabel   = alphanum | alphanum *( alphanum | "-" ) alphanum
    toplabel      = alpha | alpha *( alphanum | "-" ) alphanum
    IPv4address   = 1*digit "." 1*digit "." 1*digit "." 1*digit
    port          = *digit

Hostnames take the form described in Section 3 of [RFC1034] and
Section 2.1 of [RFC1123]: a sequence of domain labels separated by
".", each domain label starting and ending with an alphanumeric
character and possibly also containing "-" characters.

## 3.2.2-4
The rightmost
domain label of a fully qualified domain name will never start with a
digit, thus syntactically distinguishing domain names from IPv4
addresses, ...

## 3.2.2-5
... , and may be followed by a single "." if it is necessary to
   distinguish between the complete domain name and any local domain.

## 3.2.2-6
To actually be "Uniform" as a resource locator, a URL hostname should
be a fully qualified domain name.  In practice, however, the host
component may be a local domain literal.

## 3.2.2-7
The port is the network port number for the server.  Most schemes
designate protocols that have a default port number.  Another port
number may optionally be supplied, in decimal, separated from the
host by a colon.  If the port is omitted, the default port number is
assumed.

# Chapter 3.3: Path Component
## 3.3-1
The path component contains data, specific to the authority (or the
scheme if there is no authority component), identifying the resource
within the scope of that scheme and authority.

    path          = [ abs_path | opaque_part ]

    path_segments = segment *( "/" segment )
    segment       = *pchar *( ";" param )
    param         = *pchar

    pchar         = unreserved | escaped |
                    ":" | "@" | "&" | "=" | "+" | "$" | ","

## 3.3-2
The path may consist of a sequence of path segments separated by a
single slash "/" character.

## 3.3-3
Within a path segment, the characters "/", ";", "=", and "?" are reserved.

## 3.3-4
Each path segment may include a
sequence of parameters, indicated by the semicolon ";" character.

## 3.3-5
The parameters are not significant to the parsing of relative references.

# Chapter 3.4: Query Component
## 3.4-1
The query component is a string of information to be interpreted by
the resource.

    query         = *uric

## 3.4-2
Within a query component, the characters ";", "/", "?", ":", "@",
"&", "=", "+", ",", and "$" are reserved.

# Chapter 4: URI References
## 4-1
The term "URI-reference" is used here to denote the common usage of a
resource identifier.  A URI reference may be absolute or relative,
and may have additional information attached in the form of a
fragment identifier. However, "the URI" that results from such a
reference includes only the absolute URI after the fragment
identifier (if any) is removed and after any relative URI is resolved
to its absolute form.

## 4-2
    URI-reference = [ absoluteURI | relativeURI ] [ "#" fragment ]

The syntax for relative URI is a shortened form of that for absolute
URI, where some prefix of the URI is missing and certain path
components ("." and "..") have a special meaning when, and only when,
interpreting a relative path.

# Chapter 4.1: Fragment Identifier
## 4.1-1
    fragment      = *uric

The semantics of a fragment identifier is a property of the data
resulting from a retrieval action, regardless of the type of URI used
in the reference.  Therefore, the format and interpretation of
fragment identifiers is dependent on the media type [RFC2046] of the
retrieval result.

## 4.1-2
The character restrictions described in Section 2
for URI also apply to the fragment in a URI-reference.

## 4.1-3
Individual media types may define additional restrictions or structure within
the fragment for specifying different types of "partial views" that
can be identified within that media type.

## 4.1-4
A fragment identifier is only meaningful when a URI reference is
intended for retrieval and the result of that retrieval is a document
for which the identified fragment is consistently defined.

# Chapter 4.3: Parsing a URI Reference
## 4.3-1
A URI reference is typically parsed according to the four main
components and fragment identifier in order to determine what
components are present and whether the reference is relative or
absolute.  The individual components are then parsed for their
subparts and, if not opaque, to verify their validity.

## 4.3-2
Although the BNF defines what is allowed in each component, it is
ambiguous in terms of differentiating between an authority component
and a path component that begins with two slash characters.  The
greedy algorithm is used for disambiguation: the left-most matching
rule soaks up as much of the URI reference string as it is capable of
matching.  In other words, the authority component wins.

# Chapter 6: URI Normalization and Equivalence
## 6-1
In many cases, different URI strings may actually identify the
identical resource. For example, the host names used in URL are
actually case insensitive, and the URL <http://www.XEROX.com> is
equivalent to <http://www.xerox.com>.

## 6-2
In general, the rules for equivalence and definition of a normal form, if any, are scheme
dependent.

## 6-3
 When a scheme uses elements of the common syntax, it will
also use the common syntax equivalence rules, namely that the scheme
and hostname are case insensitive and a URL with an explicit ":port",
where the port is the default for the scheme, is equivalent to one
where the port is elided.