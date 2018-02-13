struct FinalFrameAlreadySentException <: Exception end

mutable struct FrameSender{T, Op}
    logic::AbstractClientLogic
    opcode::Opcode
    isfinalsent::Bool

    FrameSender{T, Op}(logic::AbstractClientLogic) where {T, Op} = new(logic, Op, false)
end

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

function sendframe(sender::TextFrameSender, data::String; isfinal::Bool = false)
    sendframe(sender, Vector{UInt8}(data); isfinal=isfinal)
end