import AppKit
import Carbon.HIToolbox

class MainViewController: NSViewController {

    private var imageView: NSImageView!
    private var textView: NSTextView!
    private var historyTableView: NSTableView!
    private var progressIndicator: NSProgressIndicator!
    private var statusLabel: NSTextField!

    private var currentImage: NSImage?
    private var ocrService: OCRService!
    private var historyManager: HistoryManager!

    private var splitView: NSSplitView!
    private var leftPanel: NSView!
    private var rightPanel: NSView!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        ocrService = OCRService()
        historyManager = HistoryManager()

        setupUI()
        setupDragAndDrop()
        loadHistory()
    }

    private func setupUI() {
        view.wantsLayer = true

        let toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view.addSubview(toolbar)

        let openButton = NSButton(title: "Open Image", target: self, action: #selector(openImageAction(_:)))
        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.bezelStyle = .rounded
        toolbar.addSubview(openButton)

        let captureButton = NSButton(title: "Capture Area", target: self, action: #selector(captureScreenAreaAction(_:)))
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.bezelStyle = .rounded
        toolbar.addSubview(captureButton)

        let copyButton = NSButton(title: "Copy Text", target: self, action: #selector(copyTextAction(_:)))
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.bezelStyle = .rounded
        toolbar.addSubview(copyButton)

        let exportButton = NSButton(title: "Export", target: self, action: #selector(exportHistoryAction(_:)))
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        exportButton.bezelStyle = .rounded
        toolbar.addSubview(exportButton)

        progressIndicator = NSProgressIndicator()
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .spinning
        progressIndicator.isIndeterminate = true
        progressIndicator.isHidden = true
        toolbar.addSubview(progressIndicator)

        statusLabel = NSTextField(labelWithString: "Drop an image here or click a button to start")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        toolbar.addSubview(statusLabel)

        splitView = NSSplitView()
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        view.addSubview(splitView)

        leftPanel = NSView()
        leftPanel.wantsLayer = true
        leftPanel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        splitView.addArrangedSubview(leftPanel)

        let rightScrollView = NSScrollView()
        rightScrollView.translatesAutoresizingMaskIntoConstraints = false
        rightScrollView.hasVerticalScroller = true
        rightScrollView.borderType = .bezelBorder

        historyTableView = NSTableView()
        historyTableView.delegate = self
        historyTableView.dataSource = self
        historyTableView.rowHeight = 60

        let textColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        textColumn.title = "Recognized Text"
        textColumn.width = 300
        historyTableView.addTableColumn(textColumn)

        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateColumn.title = "Date"
        dateColumn.width = 150
        historyTableView.addTableColumn(dateColumn)

        let confColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("confidence"))
        confColumn.title = "Confidence"
        confColumn.width = 80
        historyTableView.addTableColumn(confColumn)

        rightScrollView.documentView = historyTableView
        rightPanel = rightScrollView
        splitView.addArrangedSubview(rightPanel)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 50),

            openButton.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 12),
            openButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            captureButton.leadingAnchor.constraint(equalTo: openButton.trailingAnchor, constant: 8),
            captureButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            copyButton.leadingAnchor.constraint(equalTo: captureButton.trailingAnchor, constant: 8),
            copyButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            exportButton.leadingAnchor.constraint(equalTo: copyButton.trailingAnchor, constant: 8),
            exportButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            progressIndicator.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -12),
            progressIndicator.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            statusLabel.trailingAnchor.constraint(equalTo: progressIndicator.leadingAnchor, constant: -8),
            statusLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            splitView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupDragAndDrop() {
        let dropZone = DragDropView()
        dropZone.translatesAutoresizingMaskIntoConstraints = false
        dropZone.delegate = self
        leftPanel.addSubview(dropZone)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        scrollView.documentView = textView

        dropZone.addSubview(scrollView)

        let imageContainer = NSView()
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        imageContainer.wantsLayer = true
        imageContainer.layer?.backgroundColor = NSColor.separatorColor.cgColor

        imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageContainer.addSubview(imageView)

        let imageScrollView = NSScrollView()
        imageScrollView.translatesAutoresizingMaskIntoConstraints = false
        imageScrollView.hasVerticalScroller = true
        imageScrollView.hasHorizontalScroller = true
        imageScrollView.documentView = imageContainer
        imageScrollView.borderType = .bezelBorder

        dropZone.addSubview(imageScrollView)

        let segmentControl = NSSegmentedControl(labels: ["Image", "Text"], trackingMode: .selectOne, target: self, action: #selector(segmentChanged(_:)))
        segmentControl.translatesAutoresizingMaskIntoConstraints = false
        segmentControl.selectedSegment = 0
        dropZone.addSubview(segmentControl)

        NSLayoutConstraint.activate([
            dropZone.topAnchor.constraint(equalTo: leftPanel.topAnchor),
            dropZone.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor),
            dropZone.trailingAnchor.constraint(equalTo: leftPanel.trailingAnchor),
            dropZone.bottomAnchor.constraint(equalTo: leftPanel.bottomAnchor),

            segmentControl.topAnchor.constraint(equalTo: dropZone.topAnchor, constant: 8),
            segmentControl.centerXAnchor.constraint(equalTo: dropZone.centerXAnchor),

            imageScrollView.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 8),
            imageScrollView.leadingAnchor.constraint(equalTo: dropZone.leadingAnchor, constant: 8),
            imageScrollView.trailingAnchor.constraint(equalTo: dropZone.trailingAnchor, constant: -8),
            imageScrollView.bottomAnchor.constraint(equalTo: dropZone.bottomAnchor, constant: -8),

            imageContainer.widthAnchor.constraint(equalTo: imageScrollView.widthAnchor),
            imageContainer.heightAnchor.constraint(equalTo: imageScrollView.heightAnchor),

            imageView.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: imageContainer.widthAnchor, constant: -20),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: imageContainer.heightAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: dropZone.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: dropZone.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: dropZone.bottomAnchor, constant: -8)
        ])

        scrollView.isHidden = true
        dropZone.imageScrollView = imageScrollView
        dropZone.textScrollView = scrollView
        dropZone.segmentControl = segmentControl
    }

    @objc private func segmentChanged(_ sender: NSSegmentedControl) {
        guard let dropZone = leftPanel.subviews.first(where: { $0 is DragDropView }) as? DragDropView else { return }

        if sender.selectedSegment == 0 {
            dropZone.imageScrollView?.isHidden = false
            dropZone.textScrollView?.isHidden = true
        } else {
            dropZone.imageScrollView?.isHidden = true
            dropZone.textScrollView?.isHidden = false
        }
    }

    func openImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.beginSheetModal(for: view.window!) { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.processImage(at: url)
            }
        }
    }

    func captureScreenArea() {
        view.window?.orderOut(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            let captureWindow = ScreenCaptureWindow()
            captureWindow.onCapture = { [weak self] image in
                self?.view.window?.makeKeyAndOrderFront(nil)
                if let image = image {
                    self?.processImage(image: image)
                }
            }
            captureWindow.beginCapture()
        }
    }

    func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "ocr_export.txt"

        panel.beginSheetModal(for: view.window!) { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.historyManager.exportToFile(url: url) { success in
                    DispatchQueue.main.async {
                        if success {
                            self?.showAlert(title: "Export Successful", message: "History exported to \(url.path)")
                        } else {
                            self?.showAlert(title: "Export Failed", message: "Failed to export history")
                        }
                    }
                }
            }
        }
    }

    private func processImage(at url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            showAlert(title: "Error", message: "Failed to load image")
            return
        }
        processImage(image: image)
    }

    private func processImage(image: NSImage) {
        currentImage = image
        imageView.image = image
        setStatus("Processing...")

        if let dropZone = leftPanel.subviews.first(where: { $0 is DragDropView }) as? DragDropView {
            dropZone.segmentControl?.selectedSegment = 0
            dropZone.imageScrollView?.isHidden = false
            dropZone.textScrollView?.isHidden = true
        }

        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)

        ocrService.recognizeText(from: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.progressIndicator.stopAnimation(nil)
                self?.progressIndicator.isHidden = true

                switch result {
                case .success(let response):
                    self?.textView.string = response.text
                    self?.setStatus("Recognition complete. Confidence: \(String(format: "%.1f", response.confidence))%")
                    self?.loadHistory()
                case .failure(let error):
                    self?.textView.string = "Error: \(error.localizedDescription)"
                    self?.setStatus("Recognition failed")
                }
            }
        }
    }

    private func loadHistory() {
        historyManager.loadHistory { [weak self] records in
            DispatchQueue.main.async {
                self?.historyTableView.reloadData()
            }
        }
    }

    @objc private func openImageAction(_ sender: Any?) {
        openImage()
    }

    @objc private func captureScreenAreaAction(_ sender: Any?) {
        captureScreenArea()
    }

    @objc private func copyTextAction(_ sender: Any?) {
        let text = textView.string
        if !text.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            setStatus("Text copied to clipboard")
        }
    }

    @objc private func exportHistoryAction(_ sender: Any?) {
        exportHistory()
    }

    @objc func clearText(_ sender: Any?) {
        textView.string = ""
        currentImage = nil
        imageView.image = nil
        setStatus("Cleared")
    }

    @objc func clearHistory(_ sender: Any?) {
        historyManager.clearHistory { [weak self] in
            DispatchQueue.main.async {
                self?.historyTableView.reloadData()
                self?.setStatus("History cleared")
            }
        }
    }

    private func setStatus(_ message: String) {
        statusLabel.stringValue = message
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

extension MainViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return historyManager.records.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let record = historyManager.records[row]

        let cellIdentifier = NSUserInterfaceItemIdentifier("HistoryCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTextField

        if cell == nil {
            cell = NSTextField(labelWithString: "")
            cell?.identifier = cellIdentifier
            cell?.lineBreakMode = .byTruncatingTail
            cell?.cell?.truncatesLastVisibleLine = true
        }

        switch tableColumn?.identifier.rawValue {
        case "text":
            cell?.stringValue = record.text
        case "date":
            cell?.stringValue = record.dateString
        case "confidence":
            cell?.stringValue = String(format: "%.1f%%", record.confidence)
        default:
            break
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = historyTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < historyManager.records.count else { return }

        let record = historyManager.records[selectedRow]
        textView.string = record.text
        setStatus("Loaded from history")
    }
}

extension MainViewController: DragDropViewDelegate {

    func dragDropView(_ view: DragDropView, didReceiveImage image: NSImage) {
        processImage(image: image)
    }
}
