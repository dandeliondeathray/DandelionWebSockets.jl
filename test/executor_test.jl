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

    context("Send text messages to user") do
        frame_chan = Channel{Frame}(32)
        user_chan  = Channel{WebSocketClient.HandlerType}(32)

        executor = WebSocketClient.ClientExecutor(frame_chan, user_chan)
        WebSocketClient.text_received(executor, utf8("Hello"))
        WebSocketClient.text_received(executor, utf8("world"))
        WebSocketClient.state_closed(executor)

        @fact take!(user_chan) --> WebSocketClient.TextReceived(utf8("Hello"))
        @fact take!(user_chan) --> WebSocketClient.TextReceived(utf8("world"))
        @fact take!(user_chan) --> WebSocketClient.OnClose()
    end

end
