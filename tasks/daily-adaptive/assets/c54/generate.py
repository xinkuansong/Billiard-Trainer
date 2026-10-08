from pathlib import Path
import json
# Hand-cleaned vector paths following the user-selected standing/aiming silhouettes.
# Shared 100x100 coordinates: left/top origin, x right, y down. Both exporters consume these commands.
out = Path(__file__).resolve().parent
glyphs = json.loads((out / 'glyphs.json').read_text())
svg={};switch=[]
for name,paths in glyphs.items():
 commands=[];parts=[]
 for path in paths:
  d=[]
  for c,*v in path:
   if c=='O':
    x,y,r=v;parts.append(f'<circle cx="{x}" cy="{y}" r="{r}"/>');commands.append(f'path.addEllipse(in: CGRect(x: {x-r}, y: {y-r}, width: {r*2}, height: {r*2}))');continue
   d.append(c+' '+' '.join(map(str,v)))
   if c=='M':commands.append(f'path.move(to: CGPoint(x: {v[0]}, y: {v[1]}))')
   if c=='L':commands.append(f'path.addLine(to: CGPoint(x: {v[0]}, y: {v[1]}))')
   if c=='Q':commands.append(f'path.addQuadCurve(to: CGPoint(x: {v[2]}, y: {v[3]}), control: CGPoint(x: {v[0]}, y: {v[1]}))')
  if d:parts.append('<path d="'+' '.join(d)+'"/>')
 svg[name]='<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 100 100"><g fill="none" stroke="white" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round">'+''.join(parts)+'</g></svg>'
 (out/(name+'.svg')).write_text(svg[name]);switch.append('case .'+name+':\n                '+'\n                '.join(commands))
(out/'glyphs-svg.json').write_text(json.dumps(svg))
swift='''
/// C54: user-selected cue-holding figures. The same 100-unit paths supply the Figma SVGs.
private struct BTPlayerViewGlyph: View {
    enum Pose { case standing, aiming }
    let pose: Pose
    var body: some View {
        Canvas { context, size in
            var path = Path()
            switch pose {
                '''+'\n                '.join(switch)+'''
            }
            let t = CGAffineTransform(scaleX: size.width / 100, y: size.height / 100)
            context.stroke(path.applying(t), with: .color(HUDStyle.valueMeasured),
                           style: StrokeStyle(lineWidth: size.width * 0.055, lineCap: .round, lineJoin: .round))
        }
        // Optical centering: the cue is asymmetric, while the person's body is the anchor.
        .offset(x: pose == .standing ? 2 : -2)
        .accessibilityHidden(true)
    }
}
'''
(out / 'BTPlayerViewGlyph.generated.swift').write_text(swift)
print('Generated SVGs and Swift fragment; replace the existing BTPlayerViewGlyph after review.')
