from pathlib import Path
import sys
f=Path(sys.argv[1]);s=f.read_text()
old='''            // simultaneous 让多图 TabView 翻页 / 视频自带控件不被吞掉；本手势只处理缩放后平移 + 纵向下滑关闭。
            .simultaneousGesture(dragGesture)'''
new='''            // Reject 1x horizontal drags before recognition, rather than merely
            // doing nothing in onChanged after the pager has already lost the touch.
            .overlay {
                TutorialMediaPanSurface(scale: scale, allowsDismiss: swipeToDismiss,
                                        onChanged: updateDrag, onEnded: finishDrag)
            }'''
assert s.count(old)==1;s=s.replace(old,new)
start=s.index('    private var dragGesture: some Gesture {');end=s.index('    private func toggleZoom()',start)
s=s[:start]+'''    private func updateDrag(_ translation: CGSize) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if scale > 1 {
                offset = CGSize(width: lastOffset.width + translation.width,
                                height: lastOffset.height + translation.height)
            } else if swipeToDismiss {
                setDismissDrag(max(0, translation.height))
            }
        }
    }

    private func finishDrag(_ translation: CGSize, cancelled: Bool) {
        if scale > 1 {
            lastOffset = offset
        } else if !cancelled, swipeToDismiss,
                  translation.height > dismissThreshold,
                  translation.height > abs(translation.width) {
            onDismiss?()
        } else {
            withAnimation(.interactiveSpring()) { setDismissDrag(0) }
        }
    }

'''+s[end:]
s=s.replace('// MARK: - Looping Player (muted, no controls, auto loop)',Path(__file__).with_name('pan-surface.swift').read_text()+'\n// MARK: - Looping Player (muted, no controls, auto loop)')
old='''                    .foregroundStyle(.white, .white.opacity(0.25))
            }
        }
        .padding(.horizontal, Spacing.lg)'''
new='''                    .foregroundStyle(.white, .white.opacity(0.25))
            }
            .accessibilityLabel("关闭图片预览")
            .accessibilityIdentifier("tutorialMediaClose")
        }
        .padding(.horizontal, Spacing.lg)'''
assert s.count(old)==1;s=s.replace(old,new)
f.write_text(s)
