import Foundation
import CryptoKit

/// Small synchronous drafts, immutable background-written shot files, one current
/// writer per owner/namespace. No legacy page or cloud store consumes this format.
@MainActor
final class SpatialPracticeArchive {
    typealias Record = SpatialPracticeRecord
    private struct Draft:Codable {
        var version=2
        let owner:String
        var record:Record // lastShot is always nil here
        let historyID:UUID?
    }
    private static var writers:[String:UUID]=[:]
    private let token=UUID()
    private let defaults:UserDefaults
    private let root:URL
    private let namespace:String
    private var owner=""
    private var active=false
    private var committedID:UUID?
    private var readyID:UUID?
    private var pendingID:UUID?
    private var generation=UUID()
    private var latest:Record?
    private var migratingHistory=false
    private var operation:Task<Result<Void,Error>,Never>?
    private var completion:Task<Void,Never>?
    var onError:((String?)->Void)?
    var isActiveWriter:Bool { ownsWriter }
    #if DEBUG
    private(set) var historyEncodeCount=0
    var pendingHistory:Bool { pendingID != nil }
    var committedHistoryID:UUID? { committedID }
    private static var diagnosticEvents:[String]=[]
    var diagnosticTrace:[String] { Self.diagnosticEvents }
    #endif
    private func trace(_ event:String) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-masseJump.probe") else {return}
        Self.diagnosticEvents.append(String(format:"%.3f",ProcessInfo.processInfo.systemUptime)+" "+String(token.uuidString.prefix(8))+" "+event)
        if Self.diagnosticEvents.count>80 {Self.diagnosticEvents.removeFirst(Self.diagnosticEvents.count-80)}
        #endif
    }
    init(defaults:UserDefaults,root:URL? = nil) {
        self.defaults=defaults
        let key="spatialPractice.archiveNamespace"
        if let value=defaults.string(forKey:key),UUID(uuidString:value) != nil { namespace=value }
        else { let value=UUID().uuidString;namespace=value;defaults.set(value,forKey:key) }
        self.root=(root ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
            .appendingPathComponent("CuePhys/SpatialPractice")).appendingPathComponent(namespace)
    }
    private var writerKey:String { root.path+"/"+owner }
    private var ownsWriter:Bool { active && Self.writers[writerKey]==token }
    var draftKey:String { "spatialPractice.v2."+owner }
    private var legacyKey:String { "spatialPractice.v1."+owner }
    private var directory:URL {
        let hash=SHA256.hash(data:Data(owner.utf8)).map { String(format:"%02x",$0) }.joined()
        return root.appendingPathComponent(hash)
    }
    func historyURL(_ id:UUID)->URL { directory.appendingPathComponent(id.uuidString+".plist") }
    private func preserve(_ data:Data,key:String) {
        let backup=key+".unreadable"
        if let old=defaults.data(forKey:backup),old != data { defaults.set(data,forKey:backup+"."+UUID().uuidString) }
        else { defaults.set(data,forKey:backup) }
    }
    func begin(owner:String)->Record? {
        end();self.owner=owner;active=true;Self.writers[writerKey]=token
        trace("begin")
        committedID=nil;readyID=nil;latest=nil;migratingHistory=false;onError?(nil)
        if let data=defaults.data(forKey:draftKey) {
            do {
                let draft=try PropertyListDecoder().decode(Draft.self,from:data)
                guard draft.version==2,draft.owner==owner,draft.record.lastShot == nil,draft.record.valid else {
                    throw CocoaError(.coderReadCorrupt)
                }
                var record=draft.record
                if let id=draft.historyID {
                    do {
                        let shot=try PropertyListDecoder().decode(Record.Shot.self,from:Data(contentsOf:historyURL(id)))
                        guard shot.id==id,Record.validShot(shot) else { throw CocoaError(.coderReadCorrupt) }
                        record.lastShot=shot;committedID=id;readyID=id
                    } catch {
                        preserve(data,key:draftKey)
                        onError?("上一杆轨迹无法读取，已保留原记录；当前球形仍可练习")
                    }
                }
                latest=record;return record
            } catch {
                preserve(data,key:draftKey)
                onError?("练习记录无法读取，已保留备份并载入示例")
                return nil
            }
        }
        if let data=defaults.data(forKey:legacyKey) {
            do {
                var record=try PropertyListDecoder().decode(Record.self,from:data)
                guard record.valid else { throw CocoaError(.coderReadCorrupt) }
                // Keep the original v1 bytes, including original 85-degree shots.
                if defaults.data(forKey:legacyKey+".preserved") == nil { defaults.set(data,forKey:legacyKey+".preserved") }
                record.migrateRecoveredBoard();latest=record
                // Publish the v2 pointer only after its shot file is durable.
                if let shot=record.lastShot { migratingHistory=true;prepare(shot) } else { save(record) }
                return record
            } catch {
                preserve(data,key:legacyKey)
                onError?("旧练习记录无法读取，已保留备份并载入示例")
            }
        }
        return nil
    }
    func save(_ record:Record) {
        trace("save owns=\(ownsWriter) desired=\(record.lastShot?.id.uuidString ?? "nil") ready=\(readyID?.uuidString ?? "nil")")
        guard ownsWriter else { return }
        latest=record
        let desired=record.lastShot?.id
        let reference:UUID?
        if desired == nil { reference=nil }
        else if desired==readyID || desired==committedID { reference=desired }
        else { reference=committedID }
        if migratingHistory,let shot=record.lastShot,desired != reference { prepare(shot);return }
        migratingHistory=false
        var small=record;small.lastShot=nil;small.version=2
        guard small.valid else { onError?("球形记忆保存失败，请检查输入后重试");return }
        do {
            let encoder=PropertyListEncoder();encoder.outputFormat = .binary
            let data=try encoder.encode(Draft(owner:owner,record:small,historyID:reference))
            defaults.set(data,forKey:draftKey)
            let previous=committedID;committedID=reference
            if let previous,previous != reference,previous != readyID { removeHistory(previous) }
        } catch { onError?("球形记忆保存失败，将在下次操作时重试") }
        if let shot=record.lastShot,desired != reference { prepare(shot) }
    }
    /// Called when the immutable shot is accepted for playback, so encoding can
    /// finish during motion. The history pointer remains unchanged until settlement.
    func prepare(_ shot:Record.Shot) {
        trace("prepare owns=\(ownsWriter) id=\(shot.id)")
        guard ownsWriter,shot.id != readyID,shot.id != committedID,shot.id != pendingID else { return }
        cancelPending()
        let id=shot.id,request=UUID(),file=historyURL(shot.id)
        generation=request;pendingID=id
        #if DEBUG
        historyEncodeCount += 1
        #endif
        let work=Task.detached(priority:.utility) { ()->Result<Void,Error> in
            do {
                try Task.checkCancellation()
                guard Record.validShot(shot) else { throw CocoaError(.coderInvalidValue) }
                let encoder=PropertyListEncoder();encoder.outputFormat = .binary
                let data=try encoder.encode(shot)
                try Task.checkCancellation()
                try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
                try data.write(to:file,options:.atomic)
                return .success(())
            } catch { return .failure(error) }
        }
        operation=work
        completion=Task { [weak self] in
            let result=await work.value
            self?.trace("completion owns=\(self?.ownsWriter ?? false) current=\(self?.generation==request) result=\(result)")
            guard let self,self.ownsWriter,self.generation==request else { return }
            self.pendingID=nil;self.operation=nil;self.completion=nil
            switch result {
            case .success:
                self.onError?(nil)
                let previous=self.readyID;self.readyID=id
                if let latest=self.latest,latest.lastShot?.id==id { self.save(latest) }
                if let previous,previous != id,previous != self.committedID { self.removeHistory(previous) }
            case .failure(let error):
                if !(error is CancellationError) { self.onError?("上一杆保存失败，将在下次操作时重试") }
            }
        }
    }
    private func removeHistory(_ id:UUID) {
        let file=historyURL(id)
        guard FileManager.default.fileExists(atPath:file.path) else { return }
        do { try FileManager.default.removeItem(at:file) }
        catch { NSLog("SpatialPractice archive cleanup failed: %@",String(describing:error)) }
    }
    private func cancelPending() {
        generation=UUID();operation?.cancel();completion?.cancel();operation=nil;completion=nil;pendingID=nil
    }
    func end() {
        trace("end pending=\(pendingID?.uuidString ?? "nil") committed=\(committedID?.uuidString ?? "nil")")
        cancelPending()
        if Self.writers[writerKey]==token { Self.writers.removeValue(forKey:writerKey) }
        active=false
    }
    deinit { operation?.cancel();completion?.cancel() }
}
