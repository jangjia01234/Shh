//
//  AudioManager.swift
//  Shh
//
//  Created by sseungwonnn on 10/10/24.
//

import AVFoundation
import SwiftUI

// MARK: - 소음을 측정하고 불러오는 역할을 합니다.
final class AudioManager: ObservableObject {
    // MARK: Properties
    // 현재 사용자의 dB
    @Published var userDecibelLevel: Float = 0.0
    
    // 현재 소음 측정 상황
    @Published var isMetering: Bool = false
    
    // 배경 소음에 비해, 증가된 Loudness 비율
    @Published var loudnessIncreaseRatio: Float = 0.0
    
    // 현재 사용자의 소음 상태
    @Published var userNoiseStatus: NoiseStatus = .safe
    
    // 소음 측정을 시작한 적이 있는지
    @Published var haveStartedMetering: Bool = false
    
    private let audioRecorder: AVAudioRecorder
    
    private let backgroundNoiseMeteringTime: Int = 3 // 3초 간의 소리를 받아와 배경 소음을 갱신
    
    private let decibelMeteringTimeInterval: TimeInterval = 0.1
    private let decibelBufferSize: Int = 5 // 0.5초 간의 소리로 데시벨을 갱신
    
    private let loudnessMeteringTimeInterval: TimeInterval = 0.5
    private let loudnessBufferSize: Int = 4 // 2초 지속됐을 경우 위험도를 갱신
    
    private let distanceFromOthers: Float = 1.5 // 휴대전화와 상대방과의 거리는 1.5미터로 가정
    private let distanceFromUser = 0.5 // 휴대전화와 유저 사이의 거리는 0.5미터로 가정
    
    // 현 시점의 사용자의 dB; 0.1초 간격으로 측정
    private var currentDecibel: Float = 0.0
    
    // 소리 갱신을 위한 타이머; 주변 소음 측정 및, 현재 소음 측정에 이용
    private var timer: Timer?
    
    // 현재 사용자의 dB을 계산하기 위해 실시간 dB를 저장해두는 버퍼
    private var decibelBuffer: [Float] = []
    
    // 위험치를 계산하기 위해 loudness를 저장해두는 버퍼
    private var loudnessBuffer: [Float] = []
    
    // MARK: init
    init() throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1
        ]

        let url = URL(fileURLWithPath: "/dev/null") // 데이터를 저장하지 않음.

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        } catch {
            print("오디오 레코더를 설정하는 중 오류 발생")
            throw error
        }
    }
    
    // MARK: Methods
    /// 오디오 세션을 설정합니다.
    /// 소음 측정 전 단계에 항상 실행해줘야 하는 메서드입니다.
    func setAudioSession() throws {
        print(#function)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
            try AVAudioSession.sharedInstance().setAllowHapticsAndSystemSoundsDuringRecording(true)
        } catch {
            print("오디오 세션을 설정하는 중 오류 발생")
            throw error
        }
    }
    
    /// 배경의 평균 소음을 측정합니다.
    func meteringBackgroundNoise(completion: @escaping (Float?) -> Void) throws {
        do {
            try setAudioSession()
        } catch {
            print("오디오 세션을 설정하는 중 오류 발생")
            throw error
        }
        
        // 권한 검사
        guard checkMicrophonePermissionStatus() else {
            Task {
                await requestMicrophonePermission()
                completion(nil)
            }
            return
        }

        // 측정 시작
        audioRecorder.isMeteringEnabled = true
        audioRecorder.record()
        
        // 3초간 소음을 측정하기 위한 타이머
        var decibelSum: Float = 0.0
        var measurementCount: Int = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: decibelMeteringTimeInterval, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            // 데시벨 값 갱신
            self.audioRecorder.updateMeters()
            let dBFSDecibel = self.audioRecorder.averagePower(forChannel: 0)
            let splDecibel = self.convertToSPL(dBFS: dBFSDecibel)
            
            // 측정된 데시벨 값의 합계를 저장하고 측정 횟수를 증가시킴
            decibelSum += splDecibel
            measurementCount += 1
            
            // 3초(30회) 경과 후 평균값 계산 및 리턴
            if measurementCount >= Int(Double(backgroundNoiseMeteringTime) / decibelMeteringTimeInterval.magnitude) { // 0.1초 간격으로 3초간 측정(총 30회)
                let decibelAverage = decibelSum / Float(measurementCount)
                
                // 타이머 종료
                timer.invalidate()
                
                // 측정 종료
                audioRecorder.isMeteringEnabled = false
                audioRecorder.stop()
                
                // 측정 완료 후 평균값을 completion 핸들러로 전달
                completion(decibelAverage)
            }
        }
    }
    
    /// 내 소리가 시끄러운지 소음 측정을 시작합니다.
    func startMetering(backgroundDecibel: Float) {
        print(#function)
        // 해당 함수 호출 전에, setAudioSession() 호출 완료
        
        // 권한 검사
        guard checkMicrophonePermissionStatus() else {
            Task {
                await requestMicrophonePermission()
            }
            return
        }
        
        // 측정 시작
        audioRecorder.isMeteringEnabled = true
        audioRecorder.record()
        isMetering = true
        
        // 라이브 액티비티
        if !haveStartedMetering { // 최초 시작
            // TODO: 임시로 비활성화
            LiveActivityManager.shared.startLiveActivity(isMetering: self.isMetering)
            
            haveStartedMetering = true // 이제 최초 실행이 아님
        } else {
            Task { // 재개; 해당 동작은 업데이트
                await LiveActivityManager.shared.updateLiveActivity(isMetering: self.isMetering)
            }
        }
        
        // 타이머 설정
        var loudnessCounter: Int = 0 // decibel과 loudness 갱신 타이밍을 다르게 하기 위한 카운터
        
        timer = Timer.scheduledTimer(withTimeInterval: decibelMeteringTimeInterval, repeats: true) { _ in
            self.updateDecibelLevel()
            
            if loudnessCounter % Int(self.loudnessMeteringTimeInterval / self.decibelMeteringTimeInterval) == 0 {
                self.calculateLoudnessForDistance(backgroundDecibel: backgroundDecibel, distance: self.distanceFromOthers)
            }
            
            loudnessCounter += 1
        }
    }
    
    /// 소음 측정을 일시정지합니다.
    func pauseMetering() {
        print(#function)
        audioRecorder.pause()
        
        isMetering = false
        initializeProperties() // 데시벨 관련 프로퍼티 초기화
        
        // 라이브 액티비티 갱신
        Task {
            await LiveActivityManager.shared.updateLiveActivity(isMetering: self.isMetering)
        }
        
        NotificationManager.shared.removeAllNotifications()
        
        timer?.invalidate()
    }
    
    /// 소음 측정을 정지합니다.
    func stopMetering() {
        print(#function)
        audioRecorder.isMeteringEnabled = false
        audioRecorder.stop()
        
        isMetering = false
        haveStartedMetering = false
        initializeProperties() // 프로퍼티 초기화
        
        LiveActivityManager.shared.endLiveActivity() // 라이브 액티비티 종료
        
        NotificationManager.shared.removeAllNotifications()
        
        timer?.invalidate()
    }
    
    // MARK: Internal methods
    /// 마이크 권한 상태를 확인합니다.
    private func checkMicrophonePermissionStatus() -> Bool {
        let permissionStatus = AVAudioApplication.shared.recordPermission
        switch permissionStatus {
        case .granted:
            print("마이크 권한이 이미 허용되었습니다.")
            return true
        case .denied:
            print("마이크 권한이 거부되었습니다.")
            return false
        case .undetermined:
            print("마이크 권한이 아직 결정되지 않았습니다.")
            return false
        @unknown default:
            print("알 수 없는 권한 상태입니다.")
            return false
        }
    }
    
    /// 마이크 권한을 요청합니다.
    private func requestMicrophonePermission() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        
        if granted {
            print("마이크 권한을 요청한 결과 허용되었습니다.")
        } else {
            print("마이크 권한을 요청한 결과 거부되었습니다.")
        }
    }
    
    /// 데시벨 레벨을 갱신합니다.
    private func updateDecibelLevel() {
        audioRecorder.updateMeters()
        // 마이크로 수음한 소리 레벨
        let dBFSDecibel = audioRecorder.averagePower(forChannel: 0)
        
        // 음압 레벨(dB SPL)로 변환
        let splDecibel = convertToSPL(dBFS: dBFSDecibel)
        
        // 버퍼에 값을 저장
        decibelBuffer.append(splDecibel)
        
        // 현재 소리 받아오기
        currentDecibel = splDecibel
        
        // 버퍼가 가득차면, 평균치를 계산하여 업데이트
        if decibelBuffer.count == decibelBufferSize {
            let averageDecibel = decibelBuffer.reduce(0, +) / Float(decibelBuffer.count)
            userDecibelLevel = averageDecibel
            
            decibelBuffer.removeAll() // 초기 위치에 다시 저장, 새로운 메모리 할당하지 않음
        }
    }
    
    /// 사용자가 발생한 소리로부터 일정 거리로 떨어진 상대방이 들리는 최종적인 Loudness 계산
    private func calculateLoudnessForDistance(backgroundDecibel: Float, distance: Float) {
        // 1. 배경 소음의 Loudness 계산
        let backgroundLoudness = convertToLoudness(decibel: backgroundDecibel)
        
        // 2. 상대방이 느끼는 소음 (사용자가 내는 소음의 거리 감쇠 적용)
        let distanceRatio = distance / 0.5
        let perceivedDecibel = calculateDecibelAtDistance(originalDecibel: userDecibelLevel, distanceRatio: distanceRatio)
        
        // 3. 배경음과 상대방이 느끼는 소음의 dB 합 계산
        let combinedDecibel = combineDecibels(backgroundDecibel: backgroundDecibel, noiseDecibel: perceivedDecibel)
        
        // 4. 합산된 dB를 Loudness로 변환하여 실제 상대방이 느끼는 소음 수준을 계산
        let combinedLoudness = convertToLoudness(decibel: combinedDecibel)
        
        // 5. 배경 소음 대비 바뀐 최종 비율 계산
        loudnessIncreaseRatio = loudnessRatio(originalLoudness: backgroundLoudness, combinedLoudness: combinedLoudness)
        
        // 6. 증가된 최종 비율에 따라 위험치를 계산
        loudnessBuffer.append(loudnessIncreaseRatio)
        
        if loudnessBuffer.count >= loudnessBufferSize {
            let loudnessAverage: Float = loudnessBuffer.reduce(0, +) / Float(loudnessBufferSize)
            
            if loudnessAverage > NoiseStatus.loudnessCautionLevel {
                userNoiseStatus = .caution
            } else {
                userNoiseStatus = .safe
            }
            
            loudnessBuffer.removeFirst(2)
        }
    }
    
    /// dBFS를 dB SPL로 변환합니다.
    private func convertToSPL(dBFS: Float) -> Float {
        let splDecibel = dBFS + 100 // 선형 변환으로 가정
        return max(0, splDecibel) // 데시벨 수준이 0보다 낮지 않도록 조정
    }
    
    /// 거리에 따라 감소되어 상대방이 느끼는 음압 레벨(dB SPL)을 역제곱 법칙을 통해 계산합니다.
    private func calculateDecibelAtDistance(originalDecibel: Float, distanceRatio: Float) -> Float {
        let decibelLoss = 20.0 * log10(distanceRatio)
        return originalDecibel - decibelLoss
    }
    
    /// 두 점음원(배경 소음, 사용자가 낸 소음)의 dB 합을 계산합니다.
    private func combineDecibels(backgroundDecibel: Float, noiseDecibel: Float) -> Float {
        // 1. 각각의 dB SPL을 에너지로 변환 (에너지 계산: 10^(dB/10))
        let backgroundEnergy = pow(10, backgroundDecibel / 10)
        let noiseEnergy = pow(10, noiseDecibel / 10)
        
        // 2. 두 에너지를 합산한 후, 다시 dB SPL로 변환
        let totalEnergy = backgroundEnergy + noiseEnergy
        let totalDecibel = 10 * log10(totalEnergy)
        
        return totalDecibel
    }

    /// dB SPL을 Loudness로 변환합니다.
    /// 40 dB SPL = 1 sone 을 기준으로 변환합니다.
    private func convertToLoudness(decibel: Float) -> Float {
        return pow(2.0, (decibel - 40.0) / 10.0)
    }
    
    /// 사용자가 낸 소리로 인해 실제로 상대방이 기존보다 얼만큼 큰 소리로 느끼는지에 대한 비율을 계산합니다.
    private func loudnessRatio(originalLoudness: Float, combinedLoudness: Float) -> Float {
        return combinedLoudness / originalLoudness
    }
    
    /// 측정이 멈출 때, 값들을 초기화합니다.
    private func initializeProperties() {
        userDecibelLevel = 0.0
        currentDecibel = 0.0
        loudnessIncreaseRatio = 0.0
        decibelBuffer.removeAll()
        loudnessBuffer.removeAll()
    }
    
    // MARK: deinit
    deinit {
        audioRecorder.stop()
        isMetering = false
        
        userDecibelLevel = 0.0
        currentDecibel = 0.0
        decibelBuffer.removeAll()
        
        timer?.invalidate()
    }
}
