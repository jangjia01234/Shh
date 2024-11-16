//
//  ControlsView.swift
//  ShhWatch Watch App
//
//  Created by Jia Jang on 11/16/24.
//

import SwiftUI

struct ControlsView: View {
    // MARK: Properties
    @Binding var isMetering: Bool
    
    // MARK: Body
    var body: some View {
        HStack {
            meteringStopButton
            meteringToggleButton
        }
        .frame(maxWidth: 150)
    }
    
    // MARK: Subviews
    private var meteringStopButton: some View {
        VStack {
            Button {
                // router.pop()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            // TODO: button color가 어둡게 나오는 이슈 발생. 해결방안을 찾기 전까지 opacity로 임시 대처.
            .buttonStyle(BorderedButtonStyle(tint: Color.red.opacity(10)))
            
            Text("종료")
        }
    }
    
    private var meteringToggleButton: some View {
        VStack {
            Button {
                // TODO: 재확인 필요 (audioManger.isMetering으로 변경 예정)
                isMetering.toggle()
            } label: {
                Image(systemName: isMetering ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            // TODO: button color가 어둡게 나오는 이슈 발생. (opacity로 임시 대처)
            .buttonStyle(BorderedButtonStyle(tint: .accent.opacity(isMetering ? 2 : 10)))
            
            Text(isMetering ? "일시정지" : "재개")
        }
    }
}
