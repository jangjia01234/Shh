//
//  NoiseStatus.swift
//  Shh
//
//  Created by sseungwonnn on 10/13/24.
//

import Foundation

enum NoiseStatus: String {
    case safe
    case caution
    case danger
}

extension NoiseStatus {
    /// 소음 '주의'  단계의 기준치입니다.
    static let loudnessCautionLevel: Float = 1.3
    
    /// 소음 '위험' 단계의 기준치입니다.
    static let loudnessDangerLevel: Float = 1.5
}
