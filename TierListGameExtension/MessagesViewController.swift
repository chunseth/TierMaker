import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController {

    private var currentSession: MSSession?
    private var gameLogic: GameLogic?
    private var localParticipantID: UUID?
    private var isShowingStartGame = false

    /// When the recipient gets a message, we have the URL in didReceive. When they tap, message.url can be nil.
    /// Cache decoded state by session so we can load the game when they tap.
    private var receivedGameStateCache: [ObjectIdentifier: GameState] = [:]
    /// Layout image is often not sent to the recipient's transcript bubble (iOS limitation). When it *is* available in didReceive, we cache it so we can show it when they tap the message.
    private var receivedLayoutImageCache: [ObjectIdentifier: UIImage] = [:]
    private static let lastReceivedStateKey = "TierList.lastReceivedGameState"

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
        let hasLayout = message.layout != nil
        let layoutType = message.layout.map { String(describing: type(of: $0)) } ?? "nil"
        let templateLayout = message.layout as? MSMessageTemplateLayout
        let hasLayoutImage = templateLayout?.image != nil
        let imageSize = templateLayout?.image.map { "\($0.size.width)x\($0.size.height)" } ?? "nil"
        print("TierList.layout didReceive: layout=\(hasLayout) type=\(layoutType) hasImage=\(hasLayoutImage) imageSize=\(imageSize)")
        guard let session = message.session, let url = message.url, let state = GameState.decode(from: url) else { return }
        receivedGameStateCache[ObjectIdentifier(session)] = state
        if let data = state.encodeToData() {
            UserDefaults.standard.set(data, forKey: Self.lastReceivedStateKey)
        }
        // Capture layout image when available (only time recipient may get it). Use it when they tap the message; the transcript bubble itself is drawn by the system and we cannot fix it if iOS doesn’t show the image.
        if let layout = message.layout as? MSMessageTemplateLayout, let img = layout.image {
            receivedLayoutImageCache[ObjectIdentifier(session)] = img
            print("TierList.layout didReceive: cached layout image for session")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // When recipient taps a message, selectedMessage can be set after willBecomeActive.
        // Re-check so we show the game board instead of the category picker.
        if isShowingStartGame, let conversation = activeConversation {
            tryLoadFromSelectedMessage(conversation: conversation)
        }
    }

    override func willBecomeActive(with conversation: MSConversation) {
           super.willBecomeActive(with: conversation)
           print("DEBUG: willBecomeActive called")
           print("DEBUG: selectedMessage = \(conversation.selectedMessage != nil)")
                                                                                    
           localParticipantID = conversation.localParticipantIdentifier
           tryLoadFromSelectedMessage(conversation: conversation)
       }

    /// Called when the user taps a message in the transcript.
    override func didSelect(_ message: MSMessage, conversation: MSConversation)
     {
           super.didSelect(message, conversation: conversation)
                                                                                    
           print("DEBUG: didSelect called")
           print("DEBUG: message.url = \(message.url?.absoluteString ?? "nil")")
           let selLayout = message.layout
           let selTemplate = message.layout as? MSMessageTemplateLayout
           print("TierList.layout didSelect: layout=\(selLayout != nil) hasImage=\(selTemplate?.image != nil)")
                                                                                    
           if let loadedState = loadGameState(from: message) {
               print("DEBUG: Successfully loaded game state")
               currentSession = message.session
               var state = loadedState
               state.setParticipant2IfNeeded(conversation.localParticipantIdentifier)
               gameLogic = GameLogic(gameState: state)
               if state.isComplete {
                   showCompletedGameImage(message: message)
               } else {
                   showGameBoard()
               }
               isShowingStartGame = false
               requestPresentationStyle(.expanded)
           } else {
               print("DEBUG: Failed to load game state from message")
               print("DEBUG: message.session = \(message.session != nil)")
               print("DEBUG: cachedStates count = \(receivedGameStateCache.count)")
               print("DEBUG: UserDefaults data = \(UserDefaults.standard.data(forKey: Self.lastReceivedStateKey) != nil)")
           }
       }

    /// Load game from conversation.selectedMessage if present; otherwise show category picker.
    private func tryLoadFromSelectedMessage(conversation: MSConversation) {
           guard let message = conversation.selectedMessage else {
               print("DEBUG: No selectedMessage")
               currentSession = nil
               gameLogic = nil
               showStartGame()
               isShowingStartGame = true
               return
           }
                                                                                    
           print("DEBUG: selectedMessage found")
           print("DEBUG: message.url = \(message.url?.absoluteString ?? "nil")")
           let tryLayout = message.layout
           let tryTemplate = message.layout as? MSMessageTemplateLayout
           print("TierList.layout tryLoadFromSelectedMessage: layout=\(tryLayout != nil) hasImage=\(tryTemplate?.image != nil)")
                                                                                    
           guard let loadedState = loadGameState(from: message) else {
               print("DEBUG: loadGameState returned nil")
               print("DEBUG: Checking why...")
                                                                                    
               if let url = message.url {
                   print("DEBUG: URL exists, attempting manual decode...")
                   if let state = GameState.decode(from: url) {
                       print("DEBUG: Manual decode succeeded!")
                   } else {
                       print("DEBUG: Manual decode failed")
                   }
               } else {
                   print("DEBUG: message.url is nil")
               }
                                                                                    
               currentSession = nil
               gameLogic = nil
               showStartGame()
               isShowingStartGame = true
               return
           }
                                                                                    
           print("DEBUG: Successfully loaded state in tryLoadFromSelectedMessage")
           currentSession = message.session
           var state = loadedState
           state.setParticipant2IfNeeded(conversation.localParticipantIdentifier)
           gameLogic = GameLogic(gameState: state)
           if state.isComplete {
               showCompletedGameImage(message: message)
           } else {
               showGameBoard()
           }
           isShowingStartGame = false
       }

    /// Load GameState from message: URL → in-memory cache (didReceive). Do not fall back to UserDefaults when message has no URL (e.g. image message) or we show stale "opponent's turn".
    private func loadGameState(from message: MSMessage) -> GameState? {
        if let url = message.url, let state = GameState.decode(from: url) {
            return state
        }
        if let session = message.session, let cached = receivedGameStateCache[ObjectIdentifier(session)] {
            return cached
        }
        // Only use last-received when we had a URL that failed to decode (same session). Don't use for image taps (nil URL).
        if message.url != nil, let data = UserDefaults.standard.data(forKey: Self.lastReceivedStateKey), let state = GameState.decode(from: data) {
            return state
        }
        return nil
    }

    override func didResignActive(with conversation: MSConversation) {
        super.didResignActive(with: conversation)
        currentSession = nil
        gameLogic = nil
        receivedGameStateCache.removeAll()
        receivedLayoutImageCache.removeAll()
    }

    // MARK: - UI

    private func showStartGame() {
        isShowingStartGame = true
        view.subviews.forEach { $0.removeFromSuperview() }

        let startView = StartGameView(
            onSelectTemplate: { [weak self] template, excludedItemNames in
                self?.sendNewGame(template: template, excludedItemNames: excludedItemNames)
            },
            onCategorySelected: { [weak self] in
                self?.requestPresentationStyle(.expanded)
            }
        )
        let hosting = UIHostingController(rootView: startView)
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
    }

    /// When the user taps a completed-game message, show the final tier list image (from the message layout or generated from URL).
    private func showCompletedGameImage(message: MSMessage) {
        isShowingStartGame = false
        view.subviews.forEach { $0.removeFromSuperview() }

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let layoutImage = (message.layout as? MSMessageTemplateLayout)?.image
        let cachedImage = message.session.flatMap { receivedLayoutImageCache[ObjectIdentifier($0)] }
        print("TierList.layout showCompletedGameImage: layoutImage=\(layoutImage != nil) cachedImage=\(cachedImage != nil)")
        if let img = layoutImage ?? cachedImage {
            imageView.image = img
            print("TierList.layout showCompletedGameImage: using \(layoutImage != nil ? "layout" : "cached") image")
        } else if let state = gameLogic?.gameState, state.isComplete {
            print("TierList.layout showCompletedGameImage: using fallback render from URL")
            // Fallback: generate from URL state (recipient often never gets layout image in transcript)
            TierListRenderer.renderFinalImage(gameState: state) { [weak imageView] img in
                imageView?.image = img
            }
        }
    }

    private func showGameBoard() {
        isShowingStartGame = false
        view.subviews.forEach { $0.removeFromSuperview() }

        guard let gameLogic = gameLogic else { return }

        let gameView = GameBoardView(
            gameLogic: gameLogic,
            localParticipantID: localParticipantID,
            onDone: { [weak self] in
                self?.sendUpdatedGame()
            }
        )
        let hosting = UIHostingController(rootView: gameView)
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
    }

    // MARK: - Send message

    private func sendNewGame(template: TierTemplate, excludedItemNames: Set<String> = []) {
           guard let conversation = activeConversation,
                 let localID = localParticipantID else {
               print("DEBUG sendNewGame: Missing conversation or localID")
               return
           }
                                                                                    
           print("DEBUG sendNewGame: Starting...")
           let logic = GameLogic(template: template, creatorParticipantID: localID, excludedItemNames: excludedItemNames)
           let state = logic.gameState
                                                                                    
           print("DEBUG sendNewGame: State created, template = \(state.templateName)")
                                                                                    
           guard let url = state.encodeToMessageURL() else {
               print("DEBUG sendNewGame: encodeToMessageURL returned nil!")
               return
           }
                                                                                    
           print("DEBUG sendNewGame: URL created = \(url.absoluteString)")
                                                                                    
           let session = MSSession()
           let message = MSMessage(session: session)
           message.url = url
           print("DEBUG sendNewGame: message.url set to \(message.url?.absoluteString ?? "nil")")

           layout(for: state) { [weak self] messageLayout in
               message.layout = messageLayout
               print("DEBUG sendNewGame: layout set")
               conversation.insert(message) { (error: Error?) in
                   if let error = error {
                       print("DEBUG sendNewGame: conversation.insert failed with error: \(error)")
                   } else {
                       print("DEBUG sendNewGame: message inserted successfully")
                   }
                   self?.requestPresentationStyle(.compact)
                   self?.dismiss()
               }
           }
       }

    private func sendUpdatedGame() {
        guard let conversation = activeConversation,
              let session = currentSession,
              let gameLogic = gameLogic else { return }

        let state = gameLogic.gameState
        guard let url = state.encodeToMessageURL() else { return }

        let message = MSMessage(session: session)
        message.url = url

        if state.isComplete {
            // Send image first, then game message last so recipient's selectedMessage is the game (with URL), not the image
            showFinalImageLoadingIndicator()
            TierListRenderer.renderFinalImage(gameState: state) { [weak self] finalImage in
                self?.hideFinalImageLoadingIndicator()
                guard let self = self else { return }
                if let img = finalImage {
                    self.sendFinalImageAsMessage(image: img, templateName: state.templateName, conversation: conversation) { [weak self] in
                        self?.insertFinalGameMessage(message: message, state: state, conversation: conversation)
                    }
                } else {
                    self.insertFinalGameMessage(message: message, state: state, conversation: conversation)
                }
            }
        } else {
            layout(for: state, finalImage: nil) { [weak self] messageLayout in
                message.layout = messageLayout
                conversation.insert(message) { (_: Error?) in
                    self?.requestPresentationStyle(.compact)
                    self?.dismiss()
                }
            }
        }
    }

    private var finalImageLoadingView: UIView?

    private func showFinalImageLoadingIndicator() {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = "Creating tier list image…"
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(spinner)
        overlay.addSubview(label)
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 12),
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor)
        ])
        finalImageLoadingView = overlay
    }

    private func hideFinalImageLoadingIndicator() {
        finalImageLoadingView?.removeFromSuperview()
        finalImageLoadingView = nil
    }

    /// Writes the tier list image to a temp file and inserts it as an iMessage attachment. Calls completion when done (so we can send the game message after).
    private func sendFinalImageAsMessage(image: UIImage, templateName: String, conversation: MSConversation, completion: @escaping () -> Void) {
        guard let pngData = image.pngData() else { completion(); return }
        let sanitized = templateName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let filename = "Tier List - \(sanitized).png"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try pngData.write(to: fileURL)
            conversation.insertAttachment(fileURL, withAlternateFilename: filename) { _ in
                try? FileManager.default.removeItem(at: fileURL)
                completion()
            }
        } catch {
            print("TierList.sendFinalImageAsMessage: failed to write temp image: \(error)")
            completion()
        }
    }

    /// Inserts the final "Game complete!" message (no layout image). Call after the image so this message is last and recipient selects it.
    private func insertFinalGameMessage(message: MSMessage, state: GameState, conversation: MSConversation) {
        layout(for: state, finalImage: nil) { [weak self] messageLayout in
            message.layout = messageLayout
            conversation.insert(message) { [weak self] (_: Error?) in
                self?.requestPresentationStyle(.compact)
                self?.dismiss()
            }
        }
    }

    /// Keep layout image small so the message payload syncs. Use PNG so iOS 18’s bubble renderer may display it (some extensions that show on recipient use PNG).
    private static func layoutImageForSync(_ image: UIImage, maxLongEdge: CGFloat = 320) -> UIImage {
        let w = image.size.width, h = image.size.height
        let scale = maxLongEdge / max(w, h)
        guard scale < 1 else { return image }
        let newSize = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    private func layout(for state: GameState, finalImage: UIImage? = nil, completion: @escaping (MSMessageTemplateLayout) -> Void) {
        let layout = MSMessageTemplateLayout()
        layout.caption = state.templateName
        layout.subcaption = state.isComplete ? "Game complete!" : "Tap to play"
        // Completed game: no layout image (image is sent separately as attachment; keeps message light so recipient resolves)
        if state.isComplete {
            completion(layout)
            return
        }
        // Render at small size so layout image stays small and syncs to recipient.
        TierListRenderer.renderPreviewImage(gameState: state, size: CGSize(width: 320, height: 240)) { image in
            if let image = image {
                layout.image = Self.layoutImageForSync(image)
                print("TierList.layout layout(for:): set in-progress preview image (sender) size=\(image.size.width)x\(image.size.height)")
            } else {
                print("TierList.layout layout(for:): no preview image rendered")
            }
            completion(layout)
        }
    }
}
