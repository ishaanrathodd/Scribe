import CoreAudio
import SwiftUI

struct OnboardingMicrophoneScreen: View {
    let contentMaxWidth: CGFloat
    let onBack: () -> Void
    let onContinue: () -> Void

    @ObservedObject private var audioDeviceManager = AudioDeviceManager.shared
    @State private var selectedDeviceUID: String?

    private typealias MicrophoneDevice = (id: AudioDeviceID, uid: String, name: String)

    var body: some View {
        OnboardingStepScreen(
            stage: .microphone,
            contentMaxWidth: contentMaxWidth
        ) {
            microphoneList
        } bottomBar: {
            OnboardingBottomBar(
                leadingTitle: "Back",
                primaryTitle: "Continue",
                isPrimaryEnabled: selectedDevice != nil,
                onLeading: onBack,
                onPrimary: saveSelectionAndContinue
            )
        }
        .onAppear {
            refreshMicrophones(selectingIfNeeded: true)
            initializeSelectionIfNeeded()
        }
        .onChange(of: audioDeviceManager.availableDevices.map(\.uid)) { _, _ in
            ensureSelectionIsAvailable()
        }
    }

    private var microphoneList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if devices.isEmpty {
                emptyState
            } else {
                listHeader

                Divider()

                ForEach(devices, id: \.uid) { device in
                    Button {
                        selectedDeviceUID = device.uid
                    } label: {
                        HStack(spacing: 10) {
                            Label(device.name, systemImage: "mic")
                                .foregroundStyle(.primary)

                            Spacer(minLength: 12)

                            if selectedDeviceUID == device.uid {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 28, weight: .regular))
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if device.uid != devices.last?.uid {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .background(OnboardingCardSurface())
    }

    private var listHeader: some View {
        HStack {
            Text("Available Microphones")
                .font(.headline)

            Spacer()

            refreshButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Microphones Found",
            systemImage: "mic.slash",
            description: Text("Connect a microphone or allow microphone access, then refresh.")
        )
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var refreshButton: some View {
        Button {
            refreshMicrophones(selectingIfNeeded: false)
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.borderless)
        .help("Refresh Microphones")
    }

    private var devices: [MicrophoneDevice] {
        audioDeviceManager.availableDevices
    }

    private var selectedDevice: MicrophoneDevice? {
        guard let selectedDeviceUID else { return nil }
        return devices.first { $0.uid == selectedDeviceUID }
    }

    private func refreshMicrophones(selectingIfNeeded: Bool) {
        audioDeviceManager.loadAvailableDevices {
            if selectingIfNeeded {
                initializeSelectionIfNeeded()
            } else {
                ensureSelectionIsAvailable()
            }
        }
    }

    private func initializeSelectionIfNeeded() {
        guard selectedDevice == nil else { return }

        if let savedDeviceID = audioDeviceManager.selectedDeviceID,
            let savedDevice = devices.first(where: { $0.id == savedDeviceID })
        {
            selectedDeviceUID = savedDevice.uid
            return
        }

        if let savedDeviceUID = UserDefaults.standard.selectedAudioDeviceUID,
            let savedDevice = devices.first(where: { $0.uid == savedDeviceUID })
        {
            selectedDeviceUID = savedDevice.uid
            return
        }

        if let defaultDeviceID = audioDeviceManager.getSystemDefaultDevice(),
            let defaultDevice = devices.first(where: { $0.id == defaultDeviceID })
        {
            selectedDeviceUID = defaultDevice.uid
            return
        }

        selectedDeviceUID = devices.first?.uid
    }

    private func ensureSelectionIsAvailable() {
        if selectedDevice == nil {
            selectedDeviceUID = nil
            initializeSelectionIfNeeded()
        }
    }

    private func saveSelectionAndContinue() {
        guard let selectedDevice else { return }
        guard audioDeviceManager.availableDevices.contains(where: { $0.uid == selectedDevice.uid }) else {
            selectedDeviceUID = nil
            refreshMicrophones(selectingIfNeeded: true)
            return
        }

        audioDeviceManager.selectDeviceAndSwitchToCustomMode(id: selectedDevice.id)

        DispatchQueue.main.async {
            onContinue()
        }
    }
}
