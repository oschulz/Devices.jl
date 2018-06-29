# This file is a part of Devices.jl, licensed under the MIT License (MIT).


abstract type Device end

export Device

@inline Base.getindex(device::Device, propsym::Symbol, idxs...) = device[DevProp(propsym), idxs...]


# TODO: Identify exact Julia version for getproperty and methodswith
@static if VERSION > v"0.7.0-DEV"

# Mark as Base.@pure instead of @inline?
@inline Base.getproperty(dev::Device, propsym::Symbol) = DevProp(propsym)(dev)

# TODO: Define Base.propertynames using methodswith(device, Base.getindex)?

end # static if VERSION


struct DevProp{PropSym} end

export DevProp

Base.@pure DevProp(x) = DevProp{x}()


@inline (devprop::DevProp{PropSym})(device::Device) where PropSym = BoundDevProp{PropSym}(device)



struct BoundDevProp{PropSym,D<:Device}
    device::D
end

export BoundDevProp


# Make this a generated function?
# Mark as Base.@pure instead of @inline?
@inline function BoundDevProp{PropSym}(device::D) where {PropSym,D<:Device}
    #if hasmethod(Base.getindex, (D, DevProp{PropSym}))
        BoundDevProp{PropSym,D}(device)
    #else
    #    error("Device $device doesn't have a property $PropSym")
    #end
end



@inline Base.getindex(devprop::BoundDevProp{PropSym,D}, idxs...) where {PropSym,D} =
    devprop.device[DevProp{PropSym}(), idxs...]
