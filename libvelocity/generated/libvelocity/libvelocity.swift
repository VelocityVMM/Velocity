
public class LibVelocity: LibVelocityRefMut {
    var isOwned: Bool = true

    public override init(ptr: UnsafeMutableRawPointer) {
        super.init(ptr: ptr)
    }

    deinit {
        if isOwned {
            __swift_bridge__$LibVelocity$_free(ptr)
        }
    }
}
extension LibVelocity {
    public convenience init(_ loglevel: UInt32) {
        self.init(ptr: __swift_bridge__$LibVelocity$new(loglevel))
    }
}
public class LibVelocityRefMut: LibVelocityRef {
    public override init(ptr: UnsafeMutableRawPointer) {
        super.init(ptr: ptr)
    }
}
public class LibVelocityRef {
    var ptr: UnsafeMutableRawPointer

    public init(ptr: UnsafeMutableRawPointer) {
        self.ptr = ptr
    }
}
extension LibVelocityRef {
    public func run() {
        __swift_bridge__$LibVelocity$run(ptr)
    }
}
extension LibVelocity: Vectorizable {
    public static func vecOfSelfNew() -> UnsafeMutableRawPointer {
        __swift_bridge__$Vec_LibVelocity$new()
    }

    public static func vecOfSelfFree(vecPtr: UnsafeMutableRawPointer) {
        __swift_bridge__$Vec_LibVelocity$drop(vecPtr)
    }

    public static func vecOfSelfPush(vecPtr: UnsafeMutableRawPointer, value: LibVelocity) {
        __swift_bridge__$Vec_LibVelocity$push(vecPtr, {value.isOwned = false; return value.ptr;}())
    }

    public static func vecOfSelfPop(vecPtr: UnsafeMutableRawPointer) -> Optional<Self> {
        let pointer = __swift_bridge__$Vec_LibVelocity$pop(vecPtr)
        if pointer == nil {
            return nil
        } else {
            return (LibVelocity(ptr: pointer!) as! Self)
        }
    }

    public static func vecOfSelfGet(vecPtr: UnsafeMutableRawPointer, index: UInt) -> Optional<LibVelocityRef> {
        let pointer = __swift_bridge__$Vec_LibVelocity$get(vecPtr, index)
        if pointer == nil {
            return nil
        } else {
            return LibVelocityRef(ptr: pointer!)
        }
    }

    public static func vecOfSelfGetMut(vecPtr: UnsafeMutableRawPointer, index: UInt) -> Optional<LibVelocityRefMut> {
        let pointer = __swift_bridge__$Vec_LibVelocity$get_mut(vecPtr, index)
        if pointer == nil {
            return nil
        } else {
            return LibVelocityRefMut(ptr: pointer!)
        }
    }

    public static func vecOfSelfAsPtr(vecPtr: UnsafeMutableRawPointer) -> UnsafePointer<LibVelocityRef> {
        UnsafePointer<LibVelocityRef>(OpaquePointer(__swift_bridge__$Vec_LibVelocity$as_ptr(vecPtr)))
    }

    public static func vecOfSelfLen(vecPtr: UnsafeMutableRawPointer) -> UInt {
        __swift_bridge__$Vec_LibVelocity$len(vecPtr)
    }
}



