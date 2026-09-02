import Foundation
import Darwin

@_silgen_name("mach_vm_read_overwrite")
internal func _mach_vm_read_overwrite(
    _ target_task: mach_port_t,
    _ address: UInt64,
    _ size: UInt64,
    _ data: UInt64,
    _ outsize: UnsafeMutablePointer<UInt64>
) -> kern_return_t

@_silgen_name("mach_vm_region_recurse")
internal func _mach_vm_region_recurse(
    _ target_task: mach_port_t,
    _ address: UnsafeMutablePointer<UInt64>,
    _ size: UnsafeMutablePointer<UInt64>,
    _ object_name: UnsafeMutablePointer<mach_port_t>,
    _ info: UnsafeMutableRawPointer,
    _ infoCnt: UnsafeMutablePointer<UInt32>
) -> kern_return_t

@_silgen_name("task_info")
internal func _task_info(
    _ target_task: mach_port_t,
    _ flavor: UInt32,
    _ task_info_out: UnsafeMutableRawPointer,
    _ task_info_outCnt: UnsafeMutablePointer<UInt32>
) -> kern_return_t

struct dyld_info {
    var all_image_info_addr: UInt64
    var all_image_info_size: UInt64
    var all_image_info_format: UInt32
}

class MemoryManager {
    
    private var taskPort: mach_port_t = 0
    private var targetPID: Int32 = 0
    private var moduleBase: UInt64 = 0
    private var moduleSize: UInt64 = 0
    
    var isAttached: Bool {
        return taskPort != 0
    }
    
    var baseAddress: UInt64 {
        return moduleBase
    }
    
    func attach(to pid: Int32) -> Bool {
        targetPID = pid
        taskPort = 0
        
        let kr = task_for_pid(mach_task_self_, pid, &taskPort)
        
        guard kr == KERN_SUCCESS, taskPort != 0 else {
            print("[VEX] task_for_pid failed with error: \(kr)")
            return false
        }
        
        print("[VEX] Attached to PID \(pid)")
        return true
    }
    
    func detach() {
        if taskPort != 0 {
            mach_port_deallocate(mach_task_self_, taskPort)
            taskPort = 0
        }
        moduleBase = 0
        moduleSize = 0
    }
    
    func findModuleBase(named moduleName: String) -> UInt64? {
        guard isAttached else { return nil }
        
        if let dyldInfoAddr = getDyldInfoAddr() {
            if let base = parseDyldInfo(dyldInfoAddr, moduleName: moduleName) {
                return base
            }
        }
        
        return findModuleBaseFallback(named: moduleName)
    }
    
    private func getDyldInfoAddr() -> UInt64? {
        var dyldInfo = dyld_info(
            all_image_info_addr: 0,
            all_image_info_size: 0,
            all_image_info_format: 0
        )
        
        var count = mach_msg_type_number_t(MemoryLayout<dyld_info>.size / MemoryLayout<integer_t>.size)
        
        let kr = _task_info(
            taskPort,
            UInt32(TASK_DYLD_INFO),
            &dyldInfo,
            &count
        )
        
        guard kr == KERN_SUCCESS else { return nil }
        guard dyldInfo.all_image_info_addr > 0 else { return nil }
        
        return dyldInfo.all_image_info_addr
    }
    
    private func parseDyldInfo(_ dyldInfoAddr: UInt64, moduleName: String) -> UInt64? {
        guard let infoArrayCount: UInt32 = read(dyldInfoAddr + 4) else { return nil }
        guard let infoArray: UInt64 = read(dyldInfoAddr + 8) else { return nil }
        
        guard infoArrayCount > 0, infoArrayCount < 4096 else { return nil }
        guard infoArray > 0x100000000 else { return nil }
        
        for i in 0..<Int(infoArrayCount) {
            let imageInfoAddr = infoArray + UInt64(i * 24)
            
            guard let imageLoadAddress: UInt64 = read(imageInfoAddr) else { continue }
            guard let imageFilePathPtr: UInt64 = read(imageInfoAddr + 8) else { continue }
            guard let imagePath = readString(imageFilePathPtr, maxLength: 512) else { continue }
            
            let imageName = (imagePath as NSString).lastPathComponent.lowercased()
            
            if imageName.contains(moduleName.lowercased()) {
                moduleBase = imageLoadAddress
                moduleSize = 0x800000
                
                print("[VEX] Found \(imageName) at 0x\(String(moduleBase, radix: 16, uppercase: true))")
                return moduleBase
            }
        }
        
        return nil
    }
    
    private func findModuleBaseFallback(named moduleName: String) -> UInt64? {
        var address: UInt64 = 0
        var size: UInt64 = 0
        var objectName: mach_port_t = 0
        
        let infoSize = 152
        var infoBuffer = [UInt8](repeating: 0, count: infoSize)
        var infoCount: UInt32 = UInt32(infoSize / MemoryLayout<integer_t>.size)
        
        var largestExec: (UInt64, UInt64) = (0, 0)
        
        while true {
            let kr = _mach_vm_region_recurse(
                taskPort,
                &address,
                &size,
                &objectName,
                &infoBuffer,
                &infoCount
            )
            
            if kr != KERN_SUCCESS { break }
            
            let protection = infoBuffer.withUnsafeBytes { raw in
                raw.load(fromByteOffset: 0, as: Int32.self)
            }
            
            let isExecutable = (protection & VM_PROT_EXECUTE) != 0
            
            if isExecutable && size > largestExec.1 {
                largestExec = (address, size)
            }
            
            address += size
            
            if address > 0x80000000000 { break }
        }
        
        if largestExec.1 > 0x1000000 {
            moduleBase = largestExec.0
            moduleSize = largestExec.1
            print("[VEX] Module Base (fallback): 0x\(String(moduleBase, radix: 16, uppercase: true))")
            return moduleBase
        }
        
        return nil
    }
    
    func read<T>(_ address: UInt64) -> T? {
        let size = max(MemoryLayout<T>.size, 1)
        let alignment = max(MemoryLayout<T>.alignment, 1)
        
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: size,
            alignment: alignment
        )
        defer { buffer.deallocate() }
        
        var bytesRead: UInt64 = 0
        
        let kr = _mach_vm_read_overwrite(
            taskPort,
            address,
            UInt64(size),
            UInt64(UInt(bitPattern: buffer)),
            &bytesRead
        )
        
        guard kr == KERN_SUCCESS, bytesRead >= UInt64(size) else {
            return nil
        }
        
        if T.self == Bool.self {
            let byte = buffer.assumingMemoryBound(to: UInt8.self).pointee
            return (byte != 0) as? T
        }
        
        return buffer.assumingMemoryBound(to: T.self).pointee
    }
    
    func readBytes(_ address: UInt64, size: Int) -> Data? {
        guard size > 0 else { return nil }
        
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: size,
            alignment: MemoryLayout<UInt64>.alignment
        )
        defer { buffer.deallocate() }
        
        var bytesRead: UInt64 = 0
        
        let kr = _mach_vm_read_overwrite(
            taskPort,
            address,
            UInt64(size),
            UInt64(UInt(bitPattern: buffer)),
            &bytesRead
        )
        
        guard kr == KERN_SUCCESS, bytesRead >= UInt64(size) else {
            return nil
        }
        
        return Data(bytes: buffer, count: size)
    }
    
    func readPointer(_ address: UInt64) -> UInt64? {
        return read(address) as UInt64?
    }
    
    func readChain(_ base: UInt64, _ offsets: [UInt64]) -> UInt64? {
        var current = base
        
        for offset in offsets {
            guard let next: UInt64 = read(current + offset) else { return nil }
            current = next
        }
        
        return current
    }
    
    func readString(_ address: UInt64, maxLength: Int = 64) -> String? {
        guard let data = readBytes(address, size: maxLength) else { return nil }
        
        var bytes: [UInt8] = []
        for byte in data {
            if byte == 0 { break }
            bytes.append(byte)
        }
        
        guard !bytes.isEmpty else { return nil }
        return String(bytes: bytes, encoding: .utf8)
    }
    
    func readWideString(_ address: UInt64, maxLength: Int = 64) -> String? {
        guard let data = readBytes(address, size: maxLength * 2) else { return nil }
        
        var chars: [UInt16] = []
        var i = 0
        while i < data.count - 1 {
            let char = UInt16(data[i]) | (UInt16(data[i + 1]) << 8)
            if char == 0 { break }
            chars.append(char)
            i += 2
        }
        
        guard !chars.isEmpty else { return nil }
        return String(utf16CodeUnits: chars, count: chars.count)
    }
}
