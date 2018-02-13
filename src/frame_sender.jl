struct FinalFrameAlreadySentException <: Exception end

mutable struct TextFrameSender
    logic::AbstractClientLogic
    opcode::Opcode
    isfinalsent::Bool

    TextFrameSender(logic::AbstractClientLogic) = new(logic, OPCODE_TEXT, false)
end

function sendframe(sender::TextFrameSender, s::String; isfinal::Bool = false)
    sendframe(sender, Vector{UInt8}(s); isfinal = isfinal)
end

function sendframe(sender::TextFrameSender, data::Vector{UInt8}; isfinal::Bool = false)
    if sender.isfinalsent
        throw(FinalFrameAlreadySentException())
    end
    handle(sender.logic, SendTextFrame(data, isfinal, sender.opcode))
    sender.opcode = OPCODE_CONTINUATION
    if isfinal
        sender.isfinalsent = true
    end
end