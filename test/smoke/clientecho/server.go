package main

import (
	"flag"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/websocket"
)

var addr = flag.String("addr", "0.0.0.0:8080", "http service address")

var upgrader = websocket.Upgrader{} // use default options

func echo(w http.ResponseWriter, r *http.Request) {
	c, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Print("upgrade:", err)
		return
	}

	// Read initial message to ensure that the client is ready
	println("Connected. Waiting for client to be ready...")
	_, message, err := c.ReadMessage()
	if err != nil {
		println("Client disconnected.")
		println("")
		return
	}
	println("Client is ready:", string(message))

	n := 100000

	go writer(c, n)
	done := make(chan bool, 0)
	go reader(c, n, done)

	select {
	case <-done:
		println("Received all messages.")
		println("SUCCESS!")
		c.Close()
		os.Exit(0)
	case <-time.After(1 * time.Minute):
		println("Timed out waiting for messages.")
		println("FAILED!")
		c.Close()
		os.Exit(1)
	}
}

func writer(c *websocket.Conn, n int) {
	sent := 0
	for i := 0; i < n; i++ {
		c.WriteMessage(websocket.TextMessage, []byte("Hello"))
		sent++
	}
}

func reader(c *websocket.Conn, n int, done chan bool) {
	defer c.Close()
	received := 0
	for {
		_, _, err := c.ReadMessage()
		if err != nil {
			log.Println("read:", err)
			break
		}
		received++

		if received >= n {
			log.Printf("Received all messages. Closing connection.")
			close(done)
			break
		}
	}

	println("Received:", received)
	println("")
}

func main() {
	log.SetFlags(0)
	http.HandleFunc("/", echo)
	log.Fatal(http.ListenAndServe(*addr, nil))
}
