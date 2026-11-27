import Foundation

let evidence = URL(fileURLWithPath:CommandLine.arguments[1])
let attachments = evidence.appendingPathComponent("attachments")
let manifest = try JSONSerialization.jsonObject(with:Data(contentsOf:attachments.appendingPathComponent("manifest.json"))) as! [[String:Any]]
for arm in ["A","B"] {
    let entries = manifest.flatMap { $0["attachments"] as? [[String:Any]] ?? [] }
        .filter { ($0["suggestedHumanReadableName"] as? String)?.hasPrefix("static-cloth-capture-"+arm+"_") == true }
    guard entries.count == 1, let name = entries[0]["exportedFileName"] as? String else {
        fatalError("Missing or duplicate capture attachment")
    }
    let data = try Data(contentsOf:attachments.appendingPathComponent(name))
    guard let wrapper = FileWrapper(serializedRepresentation:data), wrapper.isDirectory else {
        fatalError("Invalid capture wrapper")
    }
    let destination = evidence.appendingPathComponent(arm+".gputrace")
    guard !FileManager.default.fileExists(atPath:destination.path) else { fatalError("Existing capture") }
    try wrapper.write(to:destination,options:.atomic,originalContentsURL:nil)
    print(destination.path)
}
