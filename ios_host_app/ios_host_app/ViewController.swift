import UIKit
import Flutter
import AVFoundation
import CoreLocation

class ViewController: UIViewController,
                      UITableViewDataSource,
                      UITableViewDelegate,
                      CLLocationManagerDelegate {

    // Connect this to your existing "Open Universal SDK" button in Storyboard
    @IBOutlet weak var openSdkButton: UIButton!

    // Logs table created in code
    private let logsTableView = UITableView(frame: .zero, style: .plain)

    private let locationManager = CLLocationManager()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        print("ViewController.viewDidLoad called")

        setupLogsTableView()

        locationManager.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload logs whenever we come back from SDK
        logsTableView.reloadData()
    }

    // MARK: - UI Setup

    private func setupLogsTableView() {
        logsTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logsTableView)

        logsTableView.dataSource = self
        logsTableView.delegate = self
        logsTableView.tableFooterView = UIView()
        logsTableView.backgroundColor = UIColor.systemGroupedBackground
        logsTableView.separatorStyle = .none
        logsTableView.rowHeight = UITableView.automaticDimension
        logsTableView.estimatedRowHeight = 80

        // Register custom cell
        logsTableView.register(KycLogCell.self, forCellReuseIdentifier: KycLogCell.reuseId)

        // Constraints: table below the button, fill to bottom
        NSLayoutConstraint.activate([
            logsTableView.topAnchor.constraint(equalTo: openSdkButton.bottomAnchor, constant: 16),
            logsTableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            logsTableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            logsTableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    // MARK: - Actions

    @IBAction func openUniversalSdk(_ sender: UIButton) {
        print("✅ openUniversalSdk tapped")
        requestPermissionsAndOpenSdk()
    }

    // If you want a Clear Logs button later, you can hook this to a bar button
    @IBAction func clearLogs(_ sender: Any) {
        KycLogStore.shared.clear()
        logsTableView.reloadData()
    }

    // MARK: - Permissions + SDK launch

    private func requestPermissionsAndOpenSdk() {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if cameraStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async {
                    self.requestLocationAndOpenSdk()
                }
            }
        } else {
            requestLocationAndOpenSdk()
        }
    }

    private func requestLocationAndOpenSdk() {
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            // For demo, open SDK immediately; popup appears on top
            openFlutterSdk()
        } else {
            openFlutterSdk()
        }
    }

    private func openFlutterSdk() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            print("❌ Failed to cast UIApplication.shared.delegate to AppDelegate")
            return
        }
        print("✅ Got AppDelegate")

        let engine = appDelegate.flutterEngine
        print("ℹ️ Flutter engine running")

        let flutterVC = FlutterViewController(
            engine: engine,
            nibName: nil,
            bundle: nil
        )
        flutterVC.modalPresentationStyle = .fullScreen
        print("✅ Created FlutterViewController")

        present(flutterVC, animated: true) {
            print("✅ FlutterViewController presented")
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return KycLogStore.shared.events.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: KycLogCell.reuseId,
            for: indexPath
        ) as? KycLogCell else {
            return UITableViewCell()
        }

        let entry = KycLogStore.shared.events[indexPath.row]

        let time = timeFormatter.string(from: entry.timestamp)
        cell.configure(entry: entry, timeString: time)

        return cell
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Optional: react to permission changes here
    }
}

/// MARK: - Custom Log Cell

final class KycLogCell: UITableViewCell {

    static let reuseId = "KycLogCell"

    private let cardView = UIView()
    private let typeLabel = PaddingLabel()
    private let stepLabel = UILabel()
    private let timeLabel = UILabel()
    private let messageLabel = UILabel()
    private let metaLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .secondarySystemBackground
        cardView.layer.cornerRadius = 12
        cardView.layer.masksToBounds = false
        cardView.layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        cardView.layer.shadowOpacity = 1
        cardView.layer.shadowRadius = 6
        cardView.layer.shadowOffset = CGSize(width: 0, height: 3)

        contentView.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
        ])

        // Type pill
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        typeLabel.textColor = .white
        typeLabel.layer.cornerRadius = 9
        typeLabel.layer.masksToBounds = true
        typeLabel.insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)

        // Step label
        stepLabel.translatesAutoresizingMaskIntoConstraints = false
        stepLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        stepLabel.textColor = .secondaryLabel

        // Time label
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = .tertiaryLabel

        // Message
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        messageLabel.textColor = .label
        messageLabel.numberOfLines = 0

        // Meta
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        metaLabel.textColor = .tertiaryLabel
        metaLabel.numberOfLines = 0

        cardView.addSubview(typeLabel)
        cardView.addSubview(stepLabel)
        cardView.addSubview(timeLabel)
        cardView.addSubview(messageLabel)
        cardView.addSubview(metaLabel)

        NSLayoutConstraint.activate([
            typeLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            typeLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),

            timeLabel.centerYAnchor.constraint(equalTo: typeLabel.centerYAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),

            stepLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 4),
            stepLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            stepLabel.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -12),

            messageLabel.topAnchor.constraint(equalTo: stepLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),

            metaLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 6),
            metaLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            metaLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            metaLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10),
        ])
    }

    func configure(entry: KycLogEntry, timeString: String) {
        // Type pill text + color
        typeLabel.text = entry.type.uppercased()
        typeLabel.backgroundColor = color(for: entry.type)

        // Step
        if let step = entry.step, !step.isEmpty {
            stepLabel.text = "Step: \(step)"
        } else {
            stepLabel.text = "Step: -"
        }

        // Time
        timeLabel.text = timeString

        // Message
        messageLabel.text = entry.message

        // Meta
        if let meta = entry.meta, !meta.isEmpty {
            metaLabel.isHidden = false
            metaLabel.text = "Meta: \(meta)"
        } else {
            metaLabel.isHidden = true
            metaLabel.text = nil
        }
    }

    private func color(for type: String) -> UIColor {
        switch type {
        case "flowStarted":
            return UIColor.systemBlue
        case "stepStarted":
            return UIColor.systemIndigo
        case "stepCompleted":
            return UIColor.systemGreen
        case "flowCompleted":
            return UIColor.systemTeal
        case "permissionRequired":
            return UIColor.systemOrange
        case "error":
            return UIColor.systemRed
        default:
            return UIColor.systemGray
        }
    }
}

/// Simple UILabel with padding
final class PaddingLabel: UILabel {
    var insets = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}
