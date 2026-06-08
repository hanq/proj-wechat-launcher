import Foundation

/// 实例备注持久化服务
/// 以 timestamp 为 key，将备注存入本地 JSON 文件
/// 文件路径: ~/Library/Application Support/WeChatLauncher/instance_notes.json
struct NotesStore {

    // MARK: - 存储路径

    private static var notesURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!

        let folder = appSupport.appendingPathComponent("WeChatLauncher")
        try? FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true
        )
        return folder.appendingPathComponent("instance_notes.json")
    }

    // MARK: - 公开方法

    /// 加载全部备注
    /// - Returns: [timestamp: note] 字典，文件不存在时返回空字典
    static func loadAllNotes() -> [String: String] {
        guard let data = try? Data(contentsOf: notesURL),
              let dict = try? JSONDecoder().decode(
                [String: String].self, from: data
              )
        else {
            return [:]
        }
        return dict
    }

    /// 保存单条备注（新增或更新）
    /// - Parameters:
    ///   - note: 备注内容，传 nil 或空字符串表示删除
    ///   - timestamp: 实例时间戳
    static func saveNote(_ note: String?, for timestamp: String) {
        var all = loadAllNotes()
        if let note = note, !note.trimmingCharacters(in: .whitespaces).isEmpty {
            all[timestamp] = note
        } else {
            all.removeValue(forKey: timestamp)
        }
        persist(all)
    }

    /// 获取单个实例的备注
    static func note(for timestamp: String) -> String? {
        return loadAllNotes()[timestamp]
    }

    // MARK: - 内部

    private static func persist(_ dict: [String: String]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        try? data.write(to: notesURL, options: .atomic)
    }
}
