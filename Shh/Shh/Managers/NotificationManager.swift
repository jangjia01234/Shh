//
//  NotificationManager.swift
//  Shh
//
//  Created by Eom Chanwoo on 10/14/24.
//

import Foundation
import SwiftUI
import UserNotifications

// MARK: - 로컬 푸시 알림 담당 매니저 (actor 적용)
final class NotificationManager {
    static let shared = NotificationManager()
    
    /// 푸시 알림 전송
    ///
    /// 타입에 맞는 알림을 전송합니다.
    func sendNotification(_ type: NotificationType) async {
        let status = await canSendNotification()
        
        if status {
            switch type {
            case .caution:
                sendCautionNotification()
            case .persistent:
                sendPersistentNotification()
            case .recurringAlert:
                sendRecurringAlertNotification()
                
            }
        } else {
            await requestPermission()
        }
    }
    
    /// 예약된 알림 모두 취소
    func removeAllNotifications() {
        print(#function)
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    /// 푸시 알림 권한 설정
    ///
    /// `.alert`, `.badge`, `.sound`에 대한 권한을 받습니다.
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            
            if granted {
                print("푸시 알림 권한 설정 성공!")
            } else {
                print("푸시 알림 권한이 거부되었습니다.")
            }
        } catch {
            print("푸시 알림 권한 요청 중 오류 발생: \(error.localizedDescription)")
        }
    }
    
    /// 푸시 알림 설정 확인
    private func canSendNotification() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings()
        switch status.authorizationStatus {
        case .authorized:
            print("알림 권한이 부여되었습니다.")
            return true
        case .provisional, .ephemeral:
            print("임시 알림 권한이 부여되었습니다.")
            return true
        case .denied:
            print("알림 권한이 거부되었습니다.")
            return false
        case .notDetermined:
            print("알림 권한이 아직 설정되지 않았습니다.")
            return false
        @unknown default:
            print("알 수 없는 권한 상태입니다.")
            return false
        }
    }
    
    /// 주의 알림 전송
    private func sendCautionNotification() {
        let content = createNotificationContent(
            subtitle: NSLocalizedString("소음 수준: ", comment: "푸시 알림 앞머리 > 소음 수준: ") + NoiseStatus.caution.message.toString(),
            body: NoiseStatus.caution.writing.toString()
        )
        
        scheduleNotification(content: content, type: .caution)
    }
    
    /// 주의 지속 알림
    ///
    /// 소음 수준이 주의 상태에서 20초 동안 머무를 경우 사용자에게 알려줍니다.
    private func sendPersistentNotification() {
        let content = createNotificationContent(
            subtitle: NSLocalizedString("지속적인 소음 발생", comment: "주의 지속 푸시 알림 제목"),
            body: NSLocalizedString("소음 상태가 20초 동안 주의에 머물렀어요!", comment: "주의 지속 푸시 알림 내용")
        )
        
        scheduleNotification(content: content, type: .persistent)
    }
    
    /// 주의 지속 반복 알림
    ///
    /// 주의 지속 알림을 받은 이후에도 계속해서 주의 수준에 머물 경우 60초 간격으로 사용자에게 알려줍니다.
    private func sendRecurringAlertNotification() {
        let content = createNotificationContent(
            subtitle: NSLocalizedString("지속적인 소음 발생", comment: "주의 지속 반복 푸시 알림 제목"),
            body: NSLocalizedString("아직까지 조심해야할 수준의 소음이 발생하고 있어요!", comment: "주의 지속 반복 푸시 알림 내용")
        )
        
        scheduleNotification(content: content, type: .recurringAlert)
    }
    
    /// 푸시 알림 내용 생성
    private func createNotificationContent(subtitle: String? = nil, body: String, sound: UNNotificationSound = .default) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = sound
        content.subtitle = subtitle ?? ""
        content.body = body
        
        return content
    }
    
    /// 푸시 알림 전송(예약)
    private func scheduleNotification(content: UNMutableNotificationContent, type: NotificationType) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: type.delay, repeats: type == .recurringAlert)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("\(type.rawValue) 알림 예약 실패: \(error.localizedDescription)")
            } else {
                print("\(type.rawValue) 알림 예약 성공: \(request.identifier)")
            }
        }
    }
}

enum NotificationType: String {
    case caution = "주의"
    case persistent = "주의 지속"
    case recurringAlert = "주의 지속 반복"
    
    var delay: TimeInterval {
        switch self {
        case .caution: return 0.1
        case .persistent: return 20
        case .recurringAlert: return 60
        }
    }
}
