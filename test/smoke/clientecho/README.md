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

Usage
-----
Build the Docker containers using the build.sh command. Because the Docker context needs to include
all source files for DandelionWebSockets, the command needs to be executed from the project root
directory.

    DandelionWebSockets$ bash test/smoke/clientecho/build.sh

In the directory `test/smoke/clientecho`, run

    $ docker-compose up

to start both containers, and commence the test. The server will print "SUCCESS!" on a successful
test run. Both containers will stop once the test is successful. If the test fails because messages
were dropped, then the test will time out one minute after the client connected. If the client fails
to connect at all, then the containers will hang indefinitely.

Note: This can be improved by having the server container time out some time after start, even if
no client ever connects.
