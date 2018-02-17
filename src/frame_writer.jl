"""
FrameWriter is used by the protocols to write frames to a socket.

This is separate from the client protocol code, because the protocol for closing a connection is
separate from the rest of the client protocol, and both need to send frames.
"""
struct FrameWriter <: AbstractFrameWriter
    writer::IO
    rng::AbstractRNG
end

"Send a frame to the other endpoint, using the supplied payload and opcode."
function send(framewriter::FrameWriter, isfinal::Bool, opcode::Opcode, payload::Vector{UInt8})
	# Each frame is masked with four random bytes.
	mask = rand(framewriter.rng, UInt8, 4)

	# Requirement
	# @10_3-2
	#
	# We must make a copy of the payload here, for two reasons:
	# 1. Section 10 of the specification states that we MUST not be modifiable by the user during
	#    transmission.
	# 2. Masking the data will modify it, and the users data should not be modified. This was fixed
	#    in issue #12.
	masked_payload = copy(payload)
	masking!(masked_payload, mask)

	len::UInt64  = length(masked_payload)
	extended_len = 0

	if 126 <= len <= 65535
		extended_len = len
		len = 126
	elseif 65536 <= len
		extended_len = len
		len = 127
	end

	# Create a Frame and write it to the underlying socket, via the `writer` proxy.
	frame = Frame(
		isfinal, false, false, false, opcode, true, len, extended_len, mask, masked_payload)

	write(framewriter.writer, frame)
end

function sendcloseframe(framewriter::FrameWriter, status::CloseStatus; reason::String = "")
	payloadbuffer = IOBuffer()
	if status != CLOSE_STATUS_NO_STATUS
		write(payloadbuffer, hton(status.code))
		if !isempty(reason)
			write(payloadbuffer, reason)
		end
	end
	send(framewriter, true, OPCODE_CLOSE, take!(payloadbuffer))
end

closesocket(w::FrameWriter) = close(w.writer)