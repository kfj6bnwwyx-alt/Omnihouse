//
//  ToastBanner.swift
//  house connect
//
//  Non-blocking top banner used in place of SwiftUI `.alert(...)` for
//  transient status messages — "Bedroom added to group" (Pencil
//  `co524`), "Kitchen disconnected" (Pencil `pyUlJ`), etc. Alerts are
//  modal and kill whatever the user was doing; toasts animate in from
//  the top of the screen, auto-dismiss after a few seconds, and let
//  the underlying view keep working.
//
//  Usage:
//
//      @State private var toast: Toast?
//      // ...
//      .toast($toast)
//      // ...
//      toast = .success("Bedroom added to group")
//      toast = .error("Kitchen disconnected")
//
//  Toasts are a state-driven model: setting the binding shows the
//  banner, the modifier schedules an auto-dismiss task, and setting
//  to nil hides it immediately. That means a fresh `toast =` during
//  an active banner REPLACES the current one and restarts the timer
//  — we don't queue — which matches how iOS Messages / the Apple
//  Music "Added to Library" banner behave.
//

import SwiftUI

// MARK: - Toast model

/// A transient banner message. `kind` drives color + glyph; `message`
/// is the short copy rendered to the right of the glyph.
///
/// `id` is a UUID so equal-text messages dispatched back-to-back
/// still trigger a fresh animation (SwiftUI's `.animation(value:)`
/// only re-fires on value change, so two identical strings wouldn't
/// re-animate without this).
struct Toast: Identifiable, Equatable {
    enum Kind {
        case success
        case error
    }

    let id = UUID()
    let kind: Kind
    let message: String

    static func success(_ message: String) -> Toast {
        Toast(kind: .success, message: message)
    }

    static func error(_ message: String) -> Toast {
        Toast(kind: .error, message: message)
    }

    var backgroundColor: Color {
        switch kind {
        case .success: return Theme.color.success
        case .error: return Theme.color.danger
        }
    }

    var glyph: String {
        switch kind {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Banner view

/// Pure presentation — green/red pill with a glyph and message, 12pt
/// internal padding, full-width with horizontal screen inset. No
/// lifecycle, no timer; the host modifier controls visibility.
private struct ToastBannerView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.glyph)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
            Text(toast.message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(toast.backgroundColor)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, Theme.space.screenHorizontal)
    }
}

// MARK: - Host modifier

/// Overlays the banner at the top of the content and schedules an
/// auto-dismiss task whenever the binding transitions to a non-nil
/// value. Swapping to a new non-nil toast restarts the timer (the
/// `.onChange` fires on every `id` change because `Toast` is
/// `Equatable` on all stored properties including the UUID).
///
/// Default dismissal is 3 seconds — long enough to read a short
/// message, short enough not to feel stuck. Callers can override
/// via `.toast($toast, duration: 5)` for error banners that need
/// more dwell time.
private struct ToastHost: ViewModifier {
    @Binding var toast: Toast?
    let duration: TimeInterval

    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    ToastBannerView(toast: toast)
                        .padding(.top, 8)
                        .transition(
                            .move(edge: .top)
                                .combined(with: .opacity)
                        )
                        .zIndex(10)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82),
                       value: toast?.id)
            .onChange(of: toast?.id) { _, _ in
                guard toast != nil else {
                    dismissTask?.cancel()
                    dismissTask = nil
                    return
                }
                // New toast landed — cancel any previous timer and
                // start a fresh countdown. Capturing `toast?.id` in
                // the task means a replacement banner won't be
                // dismissed by the stale timer — we check we're
                // still the "current" toast before clearing.
                dismissTask?.cancel()
                let myID = toast?.id
                dismissTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(duration))
                    if !Task.isCancelled, toast?.id == myID {
                        toast = nil
                    }
                }
            }
    }
}

extension View {
    /// Attaches a top-of-screen toast banner driven by the given
    /// binding. Set the binding to a `Toast` value to show the
    /// banner; it auto-dismisses after `duration` seconds (default
    /// 3). Setting it to nil hides immediately.
    func toast(_ toast: Binding<Toast?>, duration: TimeInterval = 3) -> some View {
        modifier(ToastHost(toast: toast, duration: duration))
    }
}
