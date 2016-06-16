# This file merely define abstract types used by the proxies that glue the different parts together.
export AbstractClientLogic

abstract AbstractHandlerTaskProxy <: TaskProxy
abstract AbstractClientTaskProxy <: TaskProxy
abstract AbstractWriterTaskProxy <: TaskProxy

abstract AbstractClientLogic
abstract AbstractPinger
abstract AbstractPonger

pong_missed(l::AbstractClientLogic) = error("pong_missed undefined for $(typeof(l))")