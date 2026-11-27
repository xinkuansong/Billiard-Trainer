import SwiftUI

struct BTSpatialElevationWheel:View {
    @Environment(\.teachingInstrumentActivity) private var reportActivity
    let value:Double
    let enabled:Bool
    let width:CGFloat
    let onNudge:(Float)->Void
    var identifier = "masseJump.elevation"
    var body:some View {
        VStack(spacing:0) {
            BTAimWheel(onNudge:onNudge,degreesPerPoint:0.20,degreeHapticEnabled:false,travelHapticEnabled:true,
                onDragActiveChanged:{ reportActivity?($0) },visibleWidth:18,showsDirectionLabel:false)
                .frame(width:32,height:width)
                .rotationEffect(.degrees(90))
                .frame(width:width,height:32)
                .accessibilityLabel("抬杆角度").accessibilityValue("\(Int(value.rounded()))度")
                .accessibilityHint("右划增大抬杆角度，左划减小抬杆角度")
                .accessibilityIdentifier(identifier)
            Text("抬杆 \(Int(value.rounded()))°").font(.btMicro).monospacedDigit().foregroundStyle(.white)
        }
            .frame(width:width).disabled(!enabled).opacity(enabled ? 1 : 0.3)
            .freeControlItem("shot.elevation",name:"抬杆角度")
    }
}
