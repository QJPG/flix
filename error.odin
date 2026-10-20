package main

import "core:fmt"

fmt :: fmt

Generic_Error :: struct
{
    message: string,
    code:    i32,
}

Service_Error :: struct
{
    services: bit_set[Service_Type; u32]
}

Error :: union
{
    Generic_Error,
    Service_Error
}

push_service_error :: proc(e: ^Error, s: bit_set[Service_Type; u32])
{
    if e^ == nil do e^ = Service_Error {}
    err := &e.(Service_Error)
    err.services += s
}

handle_error :: proc(e: Error)
{
    switch err in e
    {
    case Service_Error:
        fmt.eprintln("Caught Service Error:")
        fmt.eprintln("->", err.services)

    case Generic_Error:
        fmt.eprintln("Caught Generic Error:")
        fmt.eprintln("->", err.code, "@", err.message)
    }

    assert(e == nil)
}
