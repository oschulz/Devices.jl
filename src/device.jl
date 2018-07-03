# This file is a part of Devices.jl, licensed under the MIT License (MIT).


struct DevProp{PropSym} end

export DevProp

Base.@pure DevProp(x) = DevProp{x}()

Base.Symbol(devprop::DevProp{PropSym}) where {PropSym} = PropSym


"""
    abstract type Device end

Abstract super-type for devices. Subtypes must implement methods of

* `Device.proptype`
* `Device.getprop`
* `Device.setprop`

For multi-valued properties, `Device.propsize` must also be implemented.

This will implicitly provide `ndims`, `getindex` and `setindex!` for the
device type.
"""
abstract type Device end

#!!! TODO: get-/setindex! on Device and BoundDevProp should auto-expand
# colons. Treat bound device properties similar to ordinary Arrays.
# view(::Device, property) should result in a BoundDevProp.
# view(::BoundDevProp, idxs...) and view(::Device, property, idxs...)
# should result in a BoundDevPropView, a BoundDevProp bound to a specific
# (range of) channel(s).

#!!! TODO: Decide on semantics of map and (customized, on Julia v0.7)
# broadcast on BoundDevProp. Support things like dev.prop[a:b] .= scalar.

#!!! TODO: Interoperability between Devices.jl and Observables.jl.


export Device


# TODO: Which Julia version exactly?
@static if VERSION >= v"0.7.0-DEV"
    @inline Base.adjoint(device::Device) = getfield(device, :_internal)
else
    @inline Base.transpose(device::Device) = getfield(device, :_internal)
end


#!!!! TODO: _getindex_impl with type assertion on return value

Base.@propagate_inbounds function Base.getindex(device::Device, devprop::DevProp, idxs...)
    pt = proptype(device, devprop)
    getprop(device, devprop, idxs...)
end

Base.@propagate_inbounds Base.getindex(device::Device, propsym::Symbol, idxs...) = device[DevProp{propsym}(), idxs...]


Base.@propagate_inbounds function Base.setindex!(device::Device, value, devprop::DevProp, idxs...)
    pt = proptype(device, devprop)
    setprop!(device, devprop, value, idxs...)
    value
end

Base.@propagate_inbounds Base.setindex!(device::Device, value, propsym::Symbol, idxs...) = device[DevProp{propsym}(), idxs...]


@inline Base.haskey(device::Device, devprop::DevProp) = hasprop(device, devprop)

@inline Base.haskey(device::Device, propsym::Symbol) = haskey(device::Device, DevProp{propsym})


_get_val_arg(::Val{x}) where x = x

@inline Base.ndims(device::Device, devprop::DevProp) = _get_val_arg(propdims(device, devprop))

@inline Base.ndims(device::Device, propsym::Symbol) = ndims(device::Device, DevProp{propsym})


# TODO: Document
function proptype end

# TODO: Document
function propsize end


# """
#     Device.propdims(device::Device, ::DevProp)::Val{N}
# 
# Subtypes of `Device` must implement methods of `propdims` to add properties
# of dimensionality `N` to a device type. Example:
# 
#     Device.propdims(device::SomeDevice, ::DevProp{:some_property}) = Val(0)
# 
# will add property `:some_property` to device type `SomeDevice`.
# """
# function propdims end


"""
    Device.hasprop(device::Device, devprop::DevProp{propsym})::Bool

Check if `device` has a property `devprop`. Should not be called directly
from user code, call

    haskey(device, devprop)

instead. Define methods of `Device.getprop` and/or `Device.setprop!` to
implement read/write access to the device property.
"""
function hasprop end

@inline function hasprop(device::Device, devprop::DevProp)
    try
        proptype(device, devprop)
        true
    catch
        false
    end
end


"""
    Device.allprops(device::Device)::Tuple{DevProp,...}

Returns a list of all device properties.

For Julia >= v0.7, `Base.propertynames(device)` is defined via
`Device.allprops`.
"""
function allprops end

@inline function allprops(device::Device)
    # TODO: Implement, e.g. via methodswith(device, Devices.proptype).
    # May need to be a generated function.
    ()
end


"""
    Device.getprop(device::Device, devprop::DevProp{propsym}, idxs...)

Methods of `Device.setprop!` must be defined for readable properties of a
device type. `propdims(device::Device, devprop)` must be defined as well.

Do not call directly from user code, call

    device[devprop, idxs...]

or

    device[propsym, idxs...]

or (Julia >= v0.7 only)

    device.propsym[idxs...]

instead, which wraps `getprop` with additional steps/checks. 
"""
function getprop end


"""
    Device.setprop!(device::Device, value, devprop::DevProp{propsym}, idxs...)

Methods of `Device.setprop!` must be defined for writeable properties of a
device type. `propdims(device::Device, devprop)` must be defined as well.

Do not call directly from user code, call

    device[devprop, idxs...] = value

or

    device[propsym, idxs...] = value

or (Julia >= v0.7 only)

    device.propsym[idxs...] = value

instead, which wraps `setprop!` with additional steps/checks.
"""
function setprop! end


#=
function checkprop(device::Device, devprop::DevProp)
    if !hasprop(device, devprop)
        throw(ArgumentError("Device $device doesn't have a property $devprop"))
    end
    nothing    
end
=#



struct DevPropType{T,N} end

export DevPropType

Base.@pure Base.eltype(::Type{DevPropType{T,N}}) where {T,N} = T
Base.@pure Base.ndims(::Type{DevPropType{T,N}}) where {T,N} = N
Base.@pure Base.ndims(x::DevPropType) = ndims(typeof(x))



struct BoundDevProp{T,N,PropSym,D<:Device}
    proptype::DevPropType{T,N}
    property::DevProp{PropSym}
    device::D

    @inline function BoundDevProp{PropSym,Device}(property::DevProp{PropSym}, device::D) where {PropSym,D<:Device}
        pt = proptype(device, property)
        T = eltype(pt)
        N = ndims(pt)
        new{T,N,PropSym,Device}(pt, property, device)
    end
end

export BoundDevProp

@inline BoundDevProp(property::DevProp{PropSym}, device::D) where {PropSym,D<:Device} =
    BoundDevProp{PropSym,Device}(property, device)

@inline BoundDevProp{PropSym}(device::D) where {PropSym,D<:Device} =
    BoundDevProp{PropSym,Device}(DevProp{PropSym}(), device)


@inline (property::DevProp)(device::Device) = BoundDevProp(property, device)


Base.@pure Base.eltype(::Type{<:BoundDevProp{T,N}}) where {T,N} = T
Base.@pure Base.ndims(::Type{<:BoundDevProp{T,N}}) where {T,N} = N
@inline Base.ndims(x::BoundDevProp) = ndims(typeof(x))


@inline Base.ndims(devprop::BoundDevProp, idxs...) =
    ndims(devprop.device, devprop.property)

Base.size(devprop::BoundDevProp{T,0}) where {T} = ()

Base.size(devprop::BoundDevProp) = propsize(devprop.device, devprop.property)

Base.@propagate_inbounds Base.getindex(devprop::BoundDevProp, idxs...) =
    devprop.device[devprop.property, idxs...]

Base.@propagate_inbounds Base.setindex!(devprop::BoundDevProp, value, idxs...) =
    devprop.device[devprop.property, idxs...] = value


@static if VERSION >= v"0.7.0-DEV.3935"
    @inline Base.getproperty(device::Device, propsym::Symbol) = DevProp(propsym)(device)

    @inline Base.propertynames(device::Device) = map(Symbol, allprops(device))
end
