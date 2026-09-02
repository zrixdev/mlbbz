import Foundation
import UIKit

struct Vector3 {
    var x: Float
    var y: Float
    var z: Float
}

struct ESPBox {
    var screenX: CGFloat
    var screenY: CGFloat
    var width: CGFloat
    var height: CGFloat
    var health: Int
    var healthMax: Int
    var isEnemy: Bool
    var isSelf: Bool
    var isDead: Bool
    var distance: Float
    var level: Int
    var guid: UInt64
    var name: String
}

enum CampType: Int {
    case none = 0
    case blue = 1
    case red = 2
    case neutral = 3
}

class EntityParser {
    
    private var memory: MemoryManager
    private var base: UInt64
    
    private var gameMapBase: UInt64 = 0
    private var selfPlayerPos: Vector3 = Vector3(x: 0, y: 0, z: 0)
    private var selfCamp: CampType = .none
    
    var screenWidth: Float = 844
    var screenHeight: Float = 390
    
    var viewMatrix: [Float] = Array(repeating: 0, count: 16)
    
    init(memory: MemoryManager, baseAddress: UInt64) {
        self.memory = memory
        self.base = baseAddress
        
        let bounds = UIScreen.main.bounds
        self.screenWidth = Float(bounds.width)
        self.screenHeight = Float(bounds.height)
    }
    
    private func getGameMapInstance() -> UInt64? {
        let instanceMethodAddr = base + MLBBOffsets.get_Instance
        
        guard let code = memory.readBytes(instanceMethodAddr, size: 16) else {
            return nil
        }
        
        let bytes = [UInt8](code)
        guard bytes.count >= 8 else { return nil }
        
        let instr1 = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) 
                   | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
        let instr2 = UInt32(bytes[4]) | (UInt32(bytes[5]) << 8) 
                   | (UInt32(bytes[6]) << 16) | (UInt32(bytes[7]) << 24)
        
        if (instr1 & 0x9F000000) != 0x90000000 { return nil }
        
        let immlo = (instr1 >> 29) & 0x3
        let immhi = (instr1 >> 5) & 0x7FFFF
        let imm = (Int(immhi) << 2) | Int(immlo)
        let pageOffset = Int(imm) << 12
        
        let pc = Int(instanceMethodAddr)
        let page = (pc & ~0xFFF) + pageOffset
        
        if (instr2 & 0xFFC00000) != 0xF9400000 { return nil }
        
        let imm12 = (instr2 >> 10) & 0xFFF
        let offset = Int(imm12) * 8
        
        let staticAddr = UInt64(page + offset)
        
        if let instancePtr: UInt64 = memory.read(staticAddr) {
            if instancePtr > 0x100000000 && instancePtr < 0x80000000000 {
                return instancePtr
            }
        }
        
        return nil
    }
    
    func parseEntities() -> [ESPBox] {
        var results: [ESPBox] = []
        
        guard let gameMap = getGameMapInstance() else {
            return results
        }
        
        self.gameMapBase = gameMap
        
        // Strategy 1: IL2CPP List<T> scan
        for offset in stride(from: 0x10, to: 0x200, by: 8) {
            let fieldPtr = gameMap + UInt64(offset)
            
            guard let listPtr: UInt64 = memory.read(fieldPtr) else { continue }
            guard listPtr > 0x100000000 && listPtr < 0x80000000000 else { continue }
            
            guard let itemsPtr: UInt64 = memory.read(listPtr + MLBBOffsets.il2cpp_ListItems) else { continue }
            guard itemsPtr > 0x100000000 && itemsPtr < 0x80000000000 else { continue }
            
            guard let size: Int32 = memory.read(listPtr + MLBBOffsets.il2cpp_ListSize) else { continue }
            guard size > 0 && size <= 20 else { continue }
            
            var listResults: [ESPBox] = []
            for i in 0..<Int(size) {
                let entityPtrAddr = itemsPtr + MLBBOffsets.il2cpp_ArrayData + UInt64(i * 8)
                guard let entityPtr: UInt64 = memory.read(entityPtrAddr) else { continue }
                guard entityPtr != 0 else { continue }
                
                if isValidEntity(entityPtr) {
                    if let box = parseEntity(entityPtr) {
                        listResults.append(box)
                    }
                }
            }
            
            if listResults.count >= 2 {
                return listResults
            }
        }
        
        // Strategy 2: Direct entity pointers
        if results.count < 2 {
            for offset in stride(from: 0x10, to: 0x200, by: 8) {
                let entPtr: UInt64 = memory.read(gameMap + UInt64(offset)) ?? 0
                
                guard entPtr != 0 else { continue }
                guard entPtr > 0x100000000 && entPtr < 0x80000000000 else { continue }
                
                if isValidEntity(entPtr) {
                    if let box = parseEntity(entPtr) {
                        results.append(box)
                    }
                }
            }
        }
        
        // Strategy 3: ShowEntity offsets
        if results.count < 2 {
            results.removeAll()
            
            for offset in stride(from: 0x10, to: 0x200, by: 8) {
                let entPtr: UInt64 = memory.read(gameMap + UInt64(offset)) ?? 0
                
                guard entPtr != 0 else { continue }
                guard entPtr > 0x100000000 && entPtr < 0x80000000000 else { continue }
                
                if isValidShowEntity(entPtr) {
                    if let box = parseShowEntity(entPtr) {
                        results.append(box)
                    }
                }
            }
        }
        
        return results
    }
    
    private func isValidEntity(_ ptr: UInt64) -> Bool {
        guard ptr > 0x100000000 && ptr < 0x80000000000 else { return false }
        
        guard let isPlayer: UInt8 = memory.read(ptr + MLBBOffsets.IsPlayer) else { return false }
        guard isPlayer == 1 else { return false }
        
        guard let guid: UInt64 = memory.read(ptr + MLBBOffsets.m_uGuid) else { return false }
        guard guid != 0 else { return false }
        
        guard let hpMax: Int32 = memory.read(ptr + MLBBOffsets.m_HpMax) else { return false }
        guard hpMax >= 0 && hpMax <= 100000 else { return false }
        
        guard let hp: Int32 = memory.read(ptr + MLBBOffsets.m_Hp) else { return false }
        guard hp >= 0 && hp <= hpMax + 1000 else { return false }
        
        guard let camp: Int32 = memory.read(ptr + MLBBOffsets.m_EntityCampType) else { return false }
        guard camp >= 0 && camp <= 3 else { return false }
        
        return true
    }
    
    private func isValidShowEntity(_ ptr: UInt64) -> Bool {
        guard ptr > 0x100000000 && ptr < 0x80000000000 else { return false }
        
        guard let isPlayer: UInt8 = memory.read(ptr + MLBBOffsets.show_IsPlayer) else { return false }
        guard isPlayer == 1 else { return false }
        
        guard let guid: UInt64 = memory.read(ptr + MLBBOffsets.show_Guid) else { return false }
        guard guid != 0 else { return false }
        
        guard let hpMax: Int32 = memory.read(ptr + MLBBOffsets.show_HpMax) else { return false }
        guard hpMax >= 0 && hpMax <= 100000 else { return false }
        
        return true
    }
    
    private func parseEntity(_ ptr: UInt64) -> ESPBox? {
        guard let hp: Int32 = memory.read(ptr + MLBBOffsets.m_Hp) else { return nil }
        guard let hpMax: Int32 = memory.read(ptr + MLBBOffsets.m_HpMax) else { return nil }
        guard let campTypeRaw: Int32 = memory.read(ptr + MLBBOffsets.m_EntityCampType) else { return nil }
        
        let isDead: Bool = ((memory.read(ptr + MLBBOffsets.m_bDeath) as UInt8?) ?? 1) != 0
        let isSelf: Bool = ((memory.read(ptr + MLBBOffsets.m_bSelf) as UInt8?) ?? 0) != 0
        let level: Int32 = (memory.read(ptr + MLBBOffsets.m_Level) as Int32?) ?? 1
        let guid: UInt64 = (memory.read(ptr + MLBBOffsets.m_uGuid) as UInt64?) ?? 0
        
        let posAddr = ptr + MLBBOffsets.m_vCachePosition
        guard let posX: Float = memory.read(posAddr),
              let posY: Float = memory.read(posAddr + 4),
              let posZ: Float = memory.read(posAddr + 8) else {
            return nil
        }
        
        let worldPos = Vector3(x: posX, y: posY, z: posZ)
        
        if isSelf {
            selfPlayerPos = worldPos
            selfCamp = CampType(rawValue: Int(campTypeRaw)) ?? .blue
        }
        
        guard let screen = worldToScreen(worldPos) else { return nil }
        
        let dx = worldPos.x - selfPlayerPos.x
        let dz = worldPos.z - selfPlayerPos.z
        let distance = sqrtf(dx * dx + dz * dz)
        
        let camp = CampType(rawValue: Int(campTypeRaw)) ?? .none
        let isEnemy: Bool
        
        if isSelf {
            isEnemy = false
        } else if camp == .none || camp == .neutral {
            isEnemy = false
        } else {
            isEnemy = (camp != selfCamp)
        }
        
        let boxHeight: CGFloat = max(30, 110 - CGFloat(distance / 8))
        let boxWidth: CGFloat = boxHeight * 0.55
        
        return ESPBox(
            screenX: screen.x,
            screenY: screen.y,
            width: boxWidth,
            height: boxHeight,
            health: Int(hp),
            healthMax: Int(hpMax),
            isEnemy: isEnemy,
            isSelf: isSelf,
            isDead: isDead,
            distance: distance,
            level: Int(level),
            guid: guid,
            name: ""
        )
    }
    
    private func parseShowEntity(_ ptr: UInt64) -> ESPBox? {
        guard let hp: Int32 = memory.read(ptr + MLBBOffsets.show_Hp) else { return nil }
        guard let hpMax: Int32 = memory.read(ptr + MLBBOffsets.show_HpMax) else { return nil }
        guard let campTypeRaw: Int32 = memory.read(ptr + MLBBOffsets.show_Camp) else { return nil }
        
        let isDead: Bool = ((memory.read(ptr + MLBBOffsets.show_IsDead) as UInt8?) ?? 1) != 0
        let isSelf: Bool = ((memory.read(ptr + MLBBOffsets.show_IsSelf) as UInt8?) ?? 0) != 0
        let level: Int32 = (memory.read(ptr + MLBBOffsets.show_Level) as Int32?) ?? 1
        let guid: UInt64 = (memory.read(ptr + MLBBOffsets.show_Guid) as UInt64?) ?? 0
        
        let posAddr = ptr + MLBBOffsets.show_PosCache
        guard let posX: Float = memory.read(posAddr),
              let posY: Float = memory.read(posAddr + 4),
              let posZ: Float = memory.read(posAddr + 8) else {
            return nil
        }
        
        let worldPos = Vector3(x: posX, y: posY, z: posZ)
        
        if isSelf {
            selfPlayerPos = worldPos
            selfCamp = CampType(rawValue: Int(campTypeRaw)) ?? .blue
        }
        
        guard let screen = worldToScreen(worldPos) else { return nil }
        
        let dx = worldPos.x - selfPlayerPos.x
        let dz = worldPos.z - selfPlayerPos.z
        let distance = sqrtf(dx * dx + dz * dz)
        
        let camp = CampType(rawValue: Int(campTypeRaw)) ?? .none
        let isEnemy: Bool
        
        if isSelf {
            isEnemy = false
        } else if camp == .none || camp == .neutral {
            isEnemy = false
        } else {
            isEnemy = (camp != selfCamp)
        }
        
        let boxHeight: CGFloat = max(30, 110 - CGFloat(distance / 8))
        let boxWidth: CGFloat = boxHeight * 0.55
        
        return ESPBox(
            screenX: screen.x,
            screenY: screen.y,
            width: boxWidth,
            height: boxHeight,
            health: Int(hp),
            healthMax: Int(hpMax),
            isEnemy: isEnemy,
            isSelf: isSelf,
            isDead: isDead,
            distance: distance,
            level: Int(level),
            guid: guid,
            name: ""
        )
    }
    
    private func worldToScreen(_ world: Vector3) -> (x: CGFloat, y: CGFloat)? {
        if viewMatrix[0] != 0 || viewMatrix[5] != 0 || viewMatrix[10] != 0 {
            return projectWithMatrix(world)
        }
        
        let screenW = screenWidth
        let screenH = screenHeight
        
        let camAngle: Float = 0.96
        let cosA = cosf(camAngle)
        let sinA = sinf(camAngle)
        
        let refX = selfPlayerPos.x
        let refZ = selfPlayerPos.z
        
        let relX = world.x - refX
        let relZ = world.z - refZ
        
        let rotX = relX * cosA - relZ * sinA
        let rotZ = relX * sinA + relZ * cosA
        
        let scale: Float = screenW / 120.0
        
        let sx = screenW / 2 + rotX * scale
        let sy = screenH / 2 + rotZ * scale * 0.55 - world.y * scale * 0.2
        
        if sx < -100 || sx > screenW + 100 || sy < -100 || sy > screenH + 100 {
            return nil
        }
        
        return (CGFloat(sx), CGFloat(sy))
    }
    
    private func projectWithMatrix(_ world: Vector3) -> (x: CGFloat, y: CGFloat)? {
        let x = world.x
        let y = world.y
        let z = world.z
        let m = viewMatrix
        
        let clipX = m[0] * x + m[4] * y + m[8] * z + m[12]
        let clipY = m[1] * x + m[5] * y + m[9] * z + m[13]
        let clipW = m[3] * x + m[7] * y + m[11] * z + m[15]
        
        guard clipW > 0.1 else { return nil }
        
        let ndcX = clipX / clipW
        let ndcY = clipY / clipW
        
        let sx = (ndcX + 1.0) * 0.5 * screenWidth
        let sy = (1.0 - ndcY) * 0.5 * screenHeight
        
        return (CGFloat(sx), CGFloat(sy))
    }
}
