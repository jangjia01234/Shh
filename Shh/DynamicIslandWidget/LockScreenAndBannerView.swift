//
//  LockScreenAndBannerView.swift
//  DynamicIslandWidgetExtension
//
//  Created by sseungwonnn on 10/28/24.
//

import SwiftUI

struct LockScreenAndBannerView: View {
    let isMetering: Bool
    let location: Location
    
    var body: some View {
        VStack {
            HStack {
                Text("Shh-!")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(location.name)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            HStack {
                Text(isMetering ? "소음을 대신 듣고 있어요!" : "측정이 일시정지되었습니다.")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                
                MeteringButton(isMetering: isMetering)
            }
        }
        .padding()
        .background(.black)
        .activityBackgroundTint(.black)
    }
}
