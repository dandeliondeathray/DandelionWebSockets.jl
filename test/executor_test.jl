import WebSocketClient: state_connecting, state_open, state_closing, state_closed,
                        on_text, on_binary, OnText, OnBinary, StateClose, StateConnecting,
                        StateOpen, StateClosing

facts("Executor") do
    context("Send frames") do
        frame_chan = Channel{Frame}(32)
        user_chan  = Channel{WebSocketClient.HandlerType}(32)

        executor = WebSocketClient.ClientExecutor(frame_chan, user_chan)
        WebSocketClient.send_frame(executor, test_frame1)
        WebSocketClient.send_frame(executor, test_frame2)
        WebSocketClient.send_frame(executor, test_frame3)

        @fact take!(frame_chan) --> test_frame1
        @fact take!(frame_chan) --> test_frame2
        @fact take!(frame_chan) --> test_frame3
    end

    context("Send text and binary messages to user") do
        frame_chan = Channel{Frame}(32)
        user_chan  = Channel{WebSocketClient.HandlerType}(32)

        executor = WebSocketClient.ClientExecutor(frame_chan, user_chan)
        WebSocketClient.on_text(executor, utf8("Hello"))
        WebSocketClient.on_text(executor, utf8("world"))
        WebSocketClient.on_binary(executor, b"\x00\x01\x02")
        WebSocketClient.state_closed(executor)

        @fact take!(user_chan) --> OnText(utf8("Hello"))
        @fact take!(user_chan) --> OnText(utf8("world"))
        @fact take!(user_chan) --> OnBinary(b"\x00\x01\x02")
        @fact take!(user_chan) --> StateClose()
    end

    context("State changes for executor") do
        frame_chan = Channel{Frame}(32)
        user_chan  = Channel{WebSocketClient.HandlerType}(32)

        executor = WebSocketClient.ClientExecutor(frame_chan, user_chan)
        state_connecting(executor)
        state_open(executor)
        state_closing(executor)
        state_closed(executor)

        @fact take!(user_chan) --> StateConnecting()
        @fact take!(user_chan) --> StateOpen()
        @fact take!(user_chan) --> StateClosing()
        @fact take!(user_chan) --> StateClose()
    end
end
