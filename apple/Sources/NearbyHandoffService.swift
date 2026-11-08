import Foundation
import MultipeerConnectivity
import SwiftUI

struct EinsteinHandoffPayload: Codable, Sendable {
    let profile: AIAgentProfile
    let question: String
    let answer: String
    let history: [ConversationTurn]
}

@MainActor
final class NearbyHandoffService: NSObject, ObservableObject {
    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published private(set) var incomingTransfer: EinsteinHandoffPayload?
    @Published private(set) var errorMessage: String?

    private let peerID = MCPeerID(displayName: "Ecrin-\(UUID().uuidString.prefix(6))")
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    func start() {
        guard session == nil else { return }

        let session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session.delegate = self
        self.session = session

        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: nil,
            serviceType: "ecrin-handoff"
        )
        advertiser.delegate = self
        self.advertiser = advertiser
        advertiser.startAdvertisingPeer()

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: "ecrin-handoff")
        browser.delegate = self
        self.browser = browser
        browser.startBrowsingForPeers()
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        connectedPeers = []
        incomingTransfer = nil
    }

    func send(_ payload: EinsteinHandoffPayload, to peer: MCPeerID) throws {
        guard let session, session.connectedPeers.contains(peer) else {
            throw NearbyHandoffError.deviceUnavailable
        }
        let data = try JSONEncoder().encode(payload)
        guard data.count <= 250_000 else {
            throw NearbyHandoffError.transferTooLarge
        }
        try session.send(data, toPeers: [peer], with: .reliable)
    }

    func acceptIncomingTransfer() -> EinsteinHandoffPayload? {
        defer { incomingTransfer = nil }
        return incomingTransfer
    }

    func declineIncomingTransfer() {
        incomingTransfer = nil
    }

    private func updateConnectedPeers() {
        connectedPeers = session?.connectedPeers ?? []
    }
}

extension NearbyHandoffService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self, let session = self.session else {
                invitationHandler(false, nil)
                return
            }
            invitationHandler(true, session)
        }
    }

    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.errorMessage = error.localizedDescription
        }
    }
}

extension NearbyHandoffService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task { @MainActor [weak self] in
            guard let self, let session = self.session else { return }
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 20)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        didNotStartBrowsingForPeers error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.errorMessage = error.localizedDescription
        }
    }

}

extension NearbyHandoffService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor [weak self] in
            self?.updateConnectedPeers()
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let payload = try JSONDecoder().decode(EinsteinHandoffPayload.self, from: data)
            Task { @MainActor [weak self] in
                self?.incomingTransfer = payload
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.errorMessage = NearbyHandoffError.invalidTransfer.localizedDescription
            }
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}

private enum NearbyHandoffError: LocalizedError {
    case deviceUnavailable
    case invalidTransfer
    case transferTooLarge

    var errorDescription: String? {
        switch self {
        case .deviceUnavailable:
            return "L’autre appareil n’est plus disponible. Rapprochez les appareils et réessayez."
        case .invalidTransfer:
            return "Le transfert reçu est invalide et n’a pas été appliqué."
        case .transferTooLarge:
            return "La conversation est trop volumineuse pour être transférée. Réduisez son historique et réessayez."
        }
    }
}
