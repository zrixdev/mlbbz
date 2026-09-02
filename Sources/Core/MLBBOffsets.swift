import Foundation

struct MLBBOffsets {
    // GameMapBase Methods (RVA)
    static let get_Instance: UInt64        = 0x3F2F90C
    static let FindAllPlayerInMap: UInt64  = 0x3F2E7A8
    
    // EntityBase Field Offsets
    static let m_Hp: UInt64            = 0xC8
    static let m_HpMax: UInt64          = 0xCC
    static let m_EntityCampType: UInt64 = 0x1DC
    static let m_bDeath: UInt64         = 0x1D0
    static let m_bSelf: UInt64          = 0x1B0
    static let m_uGuid: UInt64          = 0xA8
    static let m_ID: UInt64             = 0xAC
    static let m_Level: UInt64          = 0xB4
    static let IsPlayer: UInt64         = 0x5C
    static let m_vCachePosition: UInt64 = 0x294
    
    // ShowEntity offsets
    static let show_IsPlayer: UInt64    = 0x93
    static let show_IsDead: UInt64      = 0xCD
    static let show_Camp: UInt64        = 0xD8
    static let show_Guid: UInt64        = 0x190
    static let show_Level: UInt64       = 0x198
    static let show_Hp: UInt64          = 0x1AC
    static let show_HpMax: UInt64       = 0x1B0
    static let show_IsSelf: UInt64      = 0x250
    static let show_PosCache: UInt64    = 0x294
    
    // IL2CPP List<T> structure
    static let il2cpp_ListItems: UInt64 = 0x10
    static let il2cpp_ListSize: UInt64  = 0x18
    static let il2cpp_ArrayData: UInt64 = 0x20
}
