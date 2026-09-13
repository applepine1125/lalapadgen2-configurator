/* リリース zip に ed25519 署名を付ける道具。
 *
 * 秘密鍵は手元にだけ置き、GitHub には絶対に入れない。CI に鍵を置くと、
 * リポジトリを乗っ取った相手がその鍵で署名できてしまい、検証の意味が無くなる。
 *
 *   swift mac/tools/sign_release.swift keygen          鍵を作る(初回だけ)
 *   swift mac/tools/sign_release.swift pubkey          埋め込む公開鍵を表示する
 *   swift mac/tools/sign_release.swift sign <file>     <file>.sig を作る
 *   swift mac/tools/sign_release.swift verify <file> <sig> <pubkey>
 */

import Foundation
import CryptoKit

/* 置き場所は LALA2CONF_SIGNING_KEY で差し替えられる(動作確認用) */
let keyURL = ProcessInfo.processInfo.environment["LALA2CONF_SIGNING_KEY"].map { URL(fileURLWithPath: $0) }
    ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/lala2conf/signing.key")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func loadPrivateKey() -> Curve25519.Signing.PrivateKey {
    guard let text = try? String(contentsOf: keyURL, encoding: .utf8) else {
        fail("鍵がありません: \(keyURL.path)\n先に keygen を実行してください")
    }
    guard let raw = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else {
        fail("鍵を読めません: \(keyURL.path)")
    }
    return key
}

func keygen() {
    if FileManager.default.fileExists(atPath: keyURL.path) {
        fail("すでに鍵があります: \(keyURL.path)\n作り直すと、今の公開鍵が入ったアプリは更新できなくなります")
    }
    let key = Curve25519.Signing.PrivateKey()
    do {
        try FileManager.default.createDirectory(at: keyURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try Data((key.rawRepresentation.base64EncodedString() + "\n").utf8)
            .write(to: keyURL, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
    } catch {
        fail("鍵を保存できません: \(error.localizedDescription)")
    }
    print("秘密鍵を作りました: \(keyURL.path)(このファイルは共有しない)")
    print("公開鍵(Updater.swift に埋め込む):")
    print(key.publicKey.rawRepresentation.base64EncodedString())
}

func sign(path: String) {
    let url = URL(fileURLWithPath: path)
    guard let data = try? Data(contentsOf: url) else { fail("読めません: \(path)") }
    let key = loadPrivateKey()
    guard let signature = try? key.signature(for: data) else { fail("署名に失敗しました") }
    let sigURL = URL(fileURLWithPath: path + ".sig")
    do {
        try Data((signature.base64EncodedString() + "\n").utf8).write(to: sigURL, options: .atomic)
    } catch {
        fail("署名を保存できません: \(error.localizedDescription)")
    }
    print(sigURL.path)
}

func verify(path: String, sigPath: String, pubkeyBase64: String) {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { fail("読めません: \(path)") }
    guard let sigText = try? String(contentsOf: URL(fileURLWithPath: sigPath), encoding: .utf8),
          let signature = Data(base64Encoded: sigText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        fail("署名を読めません: \(sigPath)")
    }
    guard let rawKey = Data(base64Encoded: pubkeyBase64),
          let key = try? Curve25519.Signing.PublicKey(rawRepresentation: rawKey) else {
        fail("公開鍵を読めません")
    }
    if key.isValidSignature(signature, for: data) {
        print("ok")
    } else {
        fail("署名が合いません")
    }
}

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "keygen":
    keygen()
case "pubkey":
    print(loadPrivateKey().publicKey.rawRepresentation.base64EncodedString())
case "sign":
    guard args.count == 2 else { fail("使い方: sign <file>") }
    sign(path: args[1])
case "verify":
    guard args.count == 4 else { fail("使い方: verify <file> <sig> <pubkey base64>") }
    verify(path: args[1], sigPath: args[2], pubkeyBase64: args[3])
default:
    fail("使い方: keygen | pubkey | sign <file> | verify <file> <sig> <pubkey base64>")
}
