import AppKit
import CryptoKit

/* リリースの zip は、手元にしか無い ed25519 の鍵で署名してから公開する(mac/release.sh)。
 * ここに埋め込んだ公開鍵で検証し、合わないものは入れない。
 * 鍵を CI に置くとリポジトリを取られた相手が署名できてしまうので、置かないこと。 */
private let updatePublicKeyBase64 = "csCPvGdPtFHTl47CcyTa//gMAfV+FhpA0bsWPfcMS4Q="

final class Updater {
  private let repoOwner = "applepine1125"
  private let repoName = "lalapadgen2-configurator"
  private let tagPattern = try! NSRegularExpression(pattern: "^lala2conf-b(\\d+)$")

  private var currentBuild: Int {
    Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
  }

  func checkAtLaunch() {
    guard currentBuild > 0 else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
      self?.check(silent: true)
    }
  }

  @objc func checkFromMenu() {
    check(silent: false)
  }

  private func check(silent: Bool) {
    let listURL = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases?per_page=20")!
    var request = URLRequest(url: listURL)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("Lala2Conf-Updater", forHTTPHeaderField: "User-Agent")

    URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
      guard let self else { return }

      if let error {
        self.handleCheckFailure(silent: silent, reason: error.localizedDescription)
        return
      }
      guard let data, let releases = try? JSONDecoder().decode([GhRelease].self, from: data) else {
        self.handleCheckFailure(silent: silent, reason: "リリース情報の解析に失敗しました")
        return
      }

      var best: (build: Int, release: GhRelease)?
      for release in releases {
        let fullRange = NSRange(release.tagName.startIndex..., in: release.tagName)
        guard let match = self.tagPattern.firstMatch(in: release.tagName, range: fullRange),
          let numberRange = Range(match.range(at: 1), in: release.tagName),
          let build = Int(release.tagName[numberRange])
        else { continue }
        if best == nil || build > best!.build {
          best = (build, release)
        }
      }

      guard let best, best.build > self.currentBuild else {
        if !silent {
          DispatchQueue.main.async { self.showUpToDateAlert() }
        }
        return
      }

      guard let asset = best.release.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
        self.handleCheckFailure(silent: silent, reason: "更新アセットが見つかりません")
        return
      }
      /* 署名が無いリリースには入れ替えない(署名前の下書きが公開された場合など) */
      guard let signatureAsset = best.release.assets.first(where: { $0.name == asset.name + ".sig" }) else {
        self.handleCheckFailure(silent: silent, reason: "署名ファイル(\(asset.name).sig)が見つかりません")
        return
      }

      DispatchQueue.main.async {
        self.confirmAndUpdate(build: best.build, asset: asset, signatureAsset: signatureAsset)
      }
    }.resume()
  }

  private func handleCheckFailure(silent: Bool, reason: String) {
    guard !silent else { return }
    DispatchQueue.main.async {
      let alert = NSAlert()
      alert.messageText = "更新の確認に失敗しました"
      alert.informativeText = reason
      alert.runModal()
    }
  }

  private func showUpToDateAlert() {
    let alert = NSAlert()
    alert.messageText = "最新版です"
    alert.informativeText = "現在のバージョンが最新です(build \(currentBuild))"
    alert.runModal()
  }

  private func confirmAndUpdate(build: Int, asset: GhAsset, signatureAsset: GhAsset) {
    let alert = NSAlert()
    alert.messageText = "新しいバージョンがあります"
    alert.informativeText = "新しいバージョン(build \(build))があります。更新しますか?"
    alert.addButton(withTitle: "更新する")
    alert.addButton(withTitle: "あとで")
    guard alert.runModal() == .alertFirstButtonReturn,
      let url = URL(string: asset.browserDownloadURL),
      let signatureURL = URL(string: signatureAsset.browserDownloadURL)
    else { return }
    downloadAndInstall(from: url, signatureURL: signatureURL)
  }

  /* 署名を先に取り、その完了ハンドラの中で zip を落とす。
   * 完了ハンドラの中から同じセッションへ投げて待つと、内側の応答が返らずデッドロックする */
  private func downloadAndInstall(from url: URL, signatureURL: URL) {
    var request = URLRequest(url: signatureURL)
    request.setValue("Lala2Conf-Updater", forHTTPHeaderField: "User-Agent")
    URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
      guard let self else { return }
      do {
        guard let data else { throw error ?? UpdaterError.signatureDownloadFailed }
        self.downloadZip(from: url, signature: try self.parseSignature(data))
      } catch {
        DispatchQueue.main.async { self.showInstallError(error) }
      }
    }.resume()
  }

  private func parseSignature(_ data: Data) throws -> Data {
    let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    guard let signature = Data(base64Encoded: text), signature.count == 64 else {
      throw UpdaterError.signatureUnreadable
    }
    return signature
  }

  private func downloadZip(from url: URL, signature: Data) {
    URLSession.shared.downloadTask(with: url) { [weak self] location, _, error in
      guard let self else { return }
      /* 一時ファイルはこのクロージャを抜けると消えるので、作業用の場所へ移してから検証する */
      let workDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("lala2conf-update-\(UUID().uuidString)")
      do {
        guard let location else { throw error ?? UpdaterError.downloadFailed }
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        let zipPath = workDir.appendingPathComponent("update.zip")
        try FileManager.default.moveItem(at: location, to: zipPath)

        try self.verify(zipAt: zipPath, signature: signature)
        try self.install(zipAt: zipPath, workDir: workDir)
      } catch {
        /* 失敗した回の展開物を残さない */
        try? FileManager.default.removeItem(at: workDir)
        DispatchQueue.main.async { self.showInstallError(error) }
      }
    }.resume()
  }

  private func verify(zipAt zipPath: URL, signature: Data) throws {
    guard let rawKey = Data(base64Encoded: updatePublicKeyBase64),
      let key = try? Curve25519.Signing.PublicKey(rawRepresentation: rawKey)
    else { throw UpdaterError.publicKeyUnusable }
    let data = try Data(contentsOf: zipPath)
    guard key.isValidSignature(signature, for: data) else { throw UpdaterError.signatureMismatch }
  }

  private func install(zipAt zipPath: URL, workDir: URL) throws {
    try run("/usr/bin/ditto", ["-x", "-k", zipPath.path, workDir.path])

    let extractedApps = try FileManager.default.contentsOfDirectory(at: workDir, includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "app" }
    guard let newAppURL = extractedApps.first else {
      throw UpdaterError.appNotFoundInArchive
    }
    /* 自分で落とした zip には quarantine が付かない(Info.plist に LSFileQuarantineEnabled が無いため)ので
     * 普段は空振りするが、手で入れた zip 由来の場合に備えて残している */
    try run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newAppURL.path])

    let currentBundleURL = Bundle.main.bundleURL
    let backupURL = currentBundleURL.deletingLastPathComponent()
      .appendingPathComponent(currentBundleURL.lastPathComponent + ".old")
    try? FileManager.default.removeItem(at: backupURL)
    try FileManager.default.moveItem(at: currentBundleURL, to: backupURL)

    do {
      try FileManager.default.moveItem(at: newAppURL, to: currentBundleURL)
    } catch {
      try? FileManager.default.moveItem(at: backupURL, to: currentBundleURL)
      throw error
    }
    try? FileManager.default.removeItem(at: backupURL)
    /* 再起動を仕掛けたあとに片付けると、終了が先に来て作業用の場所が残る。ここで消しておく */
    try? FileManager.default.removeItem(at: workDir)

    /* 実行中の自分がいる間は open が既存インスタンスを前面に出すだけなので、-n で別プロセスとして起動してから終了する */
    DispatchQueue.main.async {
      let relaunch = Process()
      relaunch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
      relaunch.arguments = ["-n", currentBundleURL.path]
      try? relaunch.run()
      NSApplication.shared.terminate(nil)
    }
  }

  private func showInstallError(_ error: Error) {
    let alert = NSAlert()
    alert.messageText = "更新に失敗しました"
    alert.informativeText = (error as? UpdaterError)?.description ?? error.localizedDescription
    alert.runModal()
  }

  @discardableResult
  private func run(_ path: String, _ arguments: [String]) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw UpdaterError.commandFailed(path, process.terminationStatus)
    }
    return process.terminationStatus
  }
}

private struct GhAsset: Decodable {
  let name: String
  let browserDownloadURL: String

  private enum CodingKeys: String, CodingKey {
    case name
    case browserDownloadURL = "browser_download_url"
  }
}

private struct GhRelease: Decodable {
  let tagName: String
  let assets: [GhAsset]

  private enum CodingKeys: String, CodingKey {
    case tagName = "tag_name"
    case assets
  }
}

private enum UpdaterError: Error, CustomStringConvertible {
  case downloadFailed
  case signatureDownloadFailed
  case signatureUnreadable
  case signatureMismatch
  case publicKeyUnusable
  case appNotFoundInArchive
  case commandFailed(String, Int32)

  var description: String {
    switch self {
    case .downloadFailed: return "ダウンロードに失敗しました"
    case .signatureDownloadFailed: return "署名のダウンロードに失敗しました"
    case .signatureUnreadable: return "署名を読めません"
    case .signatureMismatch: return "署名が合いません。更新を中止しました"
    case .publicKeyUnusable: return "検証用の公開鍵が埋め込まれていません"
    case .appNotFoundInArchive: return "アーカイブ内にアプリが見つかりません"
    case .commandFailed(let path, let status): return "\(path) が失敗しました(status \(status))"
    }
  }
}
