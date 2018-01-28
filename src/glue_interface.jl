# This file merely define abstract types used by the proxies that glue the different parts together.
export AbstractClientLogic

abstract type AbstractClientTaskProxy <: TaskProxy end
abstract type AbstractWriterTaskProxy <: TaskProxy end

abstract type AbstractClientLogic end
abstract type AbstractPinger end
abstract type AbstractPonger end
