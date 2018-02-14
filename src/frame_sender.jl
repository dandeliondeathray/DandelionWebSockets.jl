"FinalFrameAlreadySentException is thrown when sendframe is called again after the last frame."
struct FinalFrameAlreadySentException <: Exception end

"""
FrameSender is used to send multi-frame messages.

You are provided a FrameSender via the client. You then send data using the
`sendframe(sender, data; isfinal=false)` method.
For the last frame you set `isfinal = true`.

After the last frame has been sent, you MAY NOT use the FrameSender again. Trying to send
another frame with the same instance of FrameSender WILL lead to an exception of type
`FinalFrameAlreadySentException`.

NOTE: While you have a `FrameSender` in which you have not sent the last frame, then
      you MAY NOT use the client to send any other messages. Interleaving messages is
      prohibited by the WebSocket protocol and will lead to the socket being closed.

NOTE: You may send frames that are individually invalid UTF-8. However, the complete message, which
      is all frames concatenated, MUST be valid UTF-8, or the other endpoint is required to fail
      the WebSocket connection.
      With the `TextFrameSender` you can use both a `String` or a `Vector{UInt8}` as the payload.
      The `Vector{UInt8}` alternative can be used to send invalid UTF-8, or possibly invalid UTF-8.

# Example

```
sender = sendmultiframetext(client)
sendframe(sender, "Hello")
sendframe(sender, "world")
sendframe(sender, "Goodbye"; isfinal=true)
```

# Example

```
sender = sendmultiframebinary(client)
sendframe(sender, b"Hello")
sendframe(sender, b"world")
sendframe(sender, b"Goodbye"; isfinal=true)
```
"""
mutable struct FrameSender{T, Op}
    logic::AbstractClientLogic
    opcode::Opcode
    isfinalsent::Bool

    FrameSender{T, Op}(logic::AbstractClientLogic) where {T, Op} = new(logic, Op, false)
end

"""
Send a frame with a payload to the other endpoint. `isfinal` must be set to true for the last frame.

After the call with `isfinal = true`, then this method MAY NOT be called again. If it is, then a
`FinalFrameAlreadySentException` will be thrown.
"""
function sendframe(sender::FrameSender{T,Op}, data::Vector{UInt8}; isfinal::Bool = false) where {T, Op}
    if sender.isfinalsent
        throw(FinalFrameAlreadySentException())
    end
    handle(sender.logic, T(data, isfinal, sender.opcode))
    sender.opcode = OPCODE_CONTINUATION
    if isfinal
        sender.isfinalsent = true
    end
end

const BinaryFrameSender = FrameSender{SendBinaryFrame, OPCODE_BINARY}
const TextFrameSender = FrameSender{SendTextFrame, OPCODE_TEXT}

"Specialization of sendframe for TextFrameSender, for sending Strings as data."
function sendframe(sender::TextFrameSender, data::String; isfinal::Bool = false)
    sendframe(sender, Vector{UInt8}(data); isfinal=isfinal)
end