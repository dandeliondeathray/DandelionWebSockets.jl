Client echo smoke test
======================
The purpose of this test is to catch any serious errors that prevents the user from even
opening a connection or responding to a message.

The test consists of a server (written in Go) and a client script (using DandelionWebSockets).
The server awaits a single connection and, after an initial message from the client to
indicate readiness, the server sends a large number of text messages to the client. It then
records the number of responses received.

The client connects to the server, and first sends a single message indicating readiness.
Then, it receives messages from the server, and for each message sends a response.

The test does not check the contents of any response, only that all responses were received
by the server.

If the server has not received all messages within a minute, then it signals failure.
