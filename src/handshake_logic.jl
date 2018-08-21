using Random

struct HTTPHandshakeLogic
    rng::AbstractRNG
end

getrequestheaders(h::HTTPHandshakeLogic) = [
    "Sec-WebSocket-Version" => "13",
    "Upgrade" => "websocket",
    "Connection" => "Upgrade"]