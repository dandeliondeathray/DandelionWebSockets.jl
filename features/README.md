Requirements
============
These are requirements created from the specification RFC 6455. They are not
meant to be normative, but to make it easier to determine what parts of the
specification are implemented, and which are not. The requirements may leave out
details that are present in the specification, although their intent should be
clear.

Tags
----
Features and scenarios have tags, which categorises and identifies them. The
tags I've used are

- @section<n>

  Identifies which section of the specification the requirement comes from.

- @4_1_P1

  This identifies a requirement from section 4.1 (4_1), in _paragraph_ 1.


- @4_1_<subject>_<n>

  Some requirements are in numbered lists, concerning a specific subject. To
  identify each list, since there may be more than one in each section, we use
  a description of the subject of the list. Each requirement is numbered
  according to the entry in the list.
  Example:
  In section 4.1 there is a list describing the establishment of a connection.
  The requirement may look like @4_1_EstablishConnection_4, indicating the
  fourth item in the list.

- @client

  The requirement applies to the client.

- @server

  The requirement applies to the server. Note that a requirement may apply to
  both client and server.

- @must

  The requirement is a MUST, according to the conformance requirements in RFC
  2119.

- @may

  The requirement is a MAY, according to the conformance requirements in RFC
  2119.

- @irrelevant

  The requirement is not relevant to DandelionWebSockets. This may be by choice,
  such as a MAY requirement, or by environment, such as this not being a browser
  library.

- @wontimplement

  The requirement may be relevant to this package, but the package will not
  implement it. This may be the case for certain SHOULD requirements.
