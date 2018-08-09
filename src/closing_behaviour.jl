"""
CloseStatusCode indicates a reason for closing the connection.
It is optionally sent as the first two bytes of a Close frames payload.
"""
struct CloseStatus
    code::UInt16
end

const CLOSE_STATUS_NORMAL                     = CloseStatus(1000)
const CLOSE_STATUS_GOING_AWAY                 = CloseStatus(1001)
const CLOSE_STATUS_PROTOCOL_ERROR             = CloseStatus(1002)
const CLOSE_STATUS_UNACCEPTABLE_DATA          = CloseStatus(1003)
const CLOSE_STATUS_RESERVED_1004              = CloseStatus(1004)
const CLOSE_STATUS_NO_STATUS                  = CloseStatus(1005)
const CLOSE_STATUS_ABNORMAL_CLOSE             = CloseStatus(1006)
const CLOSE_STATUS_INCONSISTENT_DATA          = CloseStatus(1007)
const CLOSE_STATUS_POLICY_VIOLATION           = CloseStatus(1008)
const CLOSE_STATUS_MESSAGE_TOO_BIG            = CloseStatus(1009)
const CLOSE_STATUS_EXPECTED_EXTENSION         = CloseStatus(1010)
const CLOSE_STATUS_FATAL_UNEXPECTED_CONDITION = CloseStatus(1011)
const CLOSE_STATUS_TLS_HANDSHAKE_FAILURE      = CloseStatus(1015)

struct CloseStatusAndReason
    status::CloseStatus
    reason::String
end

function readstatusandreason(frame::Frame)
    if length(frame.payload) >= 2
        buffer = IOBuffer(frame.payload)
        code = ntoh(read(buffer, UInt16))
        reason = ""
        if length(frame.payload) > 2
            reason = String(frame.payload[3:end])
        end
        CloseStatusAndReason(CloseStatus(code), reason)
    else
        CloseStatusAndReason(CLOSE_STATUS_NO_STATUS, "")
    end
end

# Requirement
# @5_5_1-4 No frames after Close frame
# @5_5_1-8 Endpoint closed
# @5_5_1-10 Client closes the connection
# @7_1_1-1 Closing the underlying connection
# @7_1_1-3 Close the connection non-cleanly when necessary
# @7_1_1-5 The client may close the TCP connection in abnormal circumstances
# @7_1_1-7 Client should wait for the server to close the TCP connection
# @7_1_2-2 Closing the connection
# @7_1_3-1 Closing handshake is started
# @7_1_4-1 Underlying connection is closed
# @7_1_4-2 Clean close
# @7_1_7-1 Clients fail the WebSocket connection
# @7_1_7-5 Connection established before fail
# @7_1_7-6 Omit the Close frame during fail
# @7_1_7-7 Processing data after WebSocket connection fail
# @7_2_1-1 Client initiated close on fail
# @7_4 Reason for closure
# @7_4_1-1 Pre-defined status codes
#
# By design, the connection behaviours do not send text or binary frames, even when requested by the
# user.

"""
Failing the WebSocket connection is an action taken at certain points in the protocol specification,
in response to error conditions.

The closing behaviour is to optionally send a Close frame, with an appropriate status code, and then
close the socket.
"""
struct FailTheConnectionBehaviour <: ClosingBehaviour
    framewriter::AbstractFrameWriter
    handler::WebSocketHandler
    status::CloseStatus
    issocketprobablyup::Bool
    reason::String

    FailTheConnectionBehaviour(w::AbstractFrameWriter,
                               handler::WebSocketHandler,
                               status::CloseStatus;
                               issocketprobablyup=true,
                               reason::String = "") = new(w, handler, status, issocketprobablyup, reason)
end

function closetheconnection(fail::FailTheConnectionBehaviour)
    if fail.issocketprobablyup
        sendcloseframe(fail.framewriter, fail.status; reason=fail.reason)
    end
    closesocket(fail.framewriter)
    state_closed(fail.handler)
end

clientprotocolinput(::FailTheConnectionBehaviour, ::ClientProtocolInput) = nothing

protocolstate(::FailTheConnectionBehaviour) = STATE_CLOSED

isclosedcleanly(::FailTheConnectionBehaviour) = false

closestatusandreason(::FailTheConnectionBehaviour) = CloseStatusAndReason(CLOSE_STATUS_ABNORMAL_CLOSE, "")

"""
Closing the WebSocket connection is a procedure for closing the connection during the normal course
the protocol lifetime.
"""
mutable struct ClientInitiatedCloseBehaviour <: ClosingBehaviour
    framewriter::AbstractFrameWriter
    handler::WebSocketHandler
    status::CloseStatus
    reason::String
    state::SocketState
    isclosereceived::Bool
    serverstatusandreason::Union{CloseStatusAndReason, Nothing}

    function ClientInitiatedCloseBehaviour(w::AbstractFrameWriter, handler::WebSocketHandler;
                                           status::CloseStatus = CLOSE_STATUS_NORMAL,
                                           reason::String = "")
        new(w, handler, status, reason, STATE_CLOSING, false, nothing)
    end
end

protocolstate(normal::ClientInitiatedCloseBehaviour) = normal.state

function closetheconnection(normal::ClientInitiatedCloseBehaviour)
    sendcloseframe(normal.framewriter, normal.status; reason = normal.reason)
    state_closing(normal.handler)
end

function clientprotocolinput(normal::ClientInitiatedCloseBehaviour, frame::FrameFromServer)
    if frame.frame.opcode == OPCODE_CLOSE
        if normal.state == STATE_CLOSING
            normal.isclosereceived = true
            if normal.serverstatusandreason == nothing
                normal.serverstatusandreason = readstatusandreason(frame.frame)
            end
        end
    end
end

function clientprotocolinput(normal::ClientInitiatedCloseBehaviour, ::SocketClosed)
    if normal.state == STATE_CLOSING
        normal.state = STATE_CLOSED
        state_closed(normal.handler)
    end
end

function clientprotocolinput(normal::ClientInitiatedCloseBehaviour, ::AbnormalNoCloseResponseReceived)
    closesocket(normal.framewriter)
end

clientprotocolinput(::ClientInitiatedCloseBehaviour, ::ClientProtocolInput) = nothing

isclosedcleanly(normal::ClientInitiatedCloseBehaviour) = normal.state == STATE_CLOSED && normal.isclosereceived

function closestatusandreason(normal::ClientInitiatedCloseBehaviour)
    if normal.serverstatusandreason == nothing
        CloseStatusAndReason(CLOSE_STATUS_ABNORMAL_CLOSE, "")
    else
        get(normal.serverstatusandreason)
    end
end

"""
The server can initiate a Close, in which case this behaviour ensures a proper close.
"""
mutable struct ServerInitiatedCloseBehaviour <: ClosingBehaviour
    framewriter::AbstractFrameWriter
    handler::WebSocketHandler
    serverstatus::CloseStatus
    serverreason::String
    state::SocketState
    issocketclosedbyserver::Bool

    function ServerInitiatedCloseBehaviour(w::AbstractFrameWriter, h::WebSocketHandler, servercloseframe::Frame)
        statusandreason = readstatusandreason(servercloseframe)
        new(w, h, statusandreason.status, statusandreason.reason, STATE_CLOSING, false)
    end
end

protocolstate(b::ServerInitiatedCloseBehaviour) = b.state

function closetheconnection(behaviour::ServerInitiatedCloseBehaviour)
    state_closing(behaviour.handler)
    sendcloseframe(behaviour.framewriter, behaviour.serverstatus; reason = "")
end

function clientprotocolinput(behaviour::ServerInitiatedCloseBehaviour, ::SocketClosed)
    behaviour.state = STATE_CLOSED
    behaviour.issocketclosedbyserver = true
    state_closed(behaviour.handler)
end

clientprotocolinput(::ServerInitiatedCloseBehaviour, ::ClientProtocolInput) = nothing

function clientprotocolinput(b::ServerInitiatedCloseBehaviour, ::AbnormalSocketNotClosedByServer)
    b.state = STATE_CLOSED
    state_closed(b.handler)
    closesocket(b.framewriter)
end

isclosedcleanly(b::ServerInitiatedCloseBehaviour) = b.state == STATE_CLOSED && b.issocketclosedbyserver

closestatusandreason(b::ServerInitiatedCloseBehaviour) = CloseStatusAndReason(b.serverstatus, b.serverreason)