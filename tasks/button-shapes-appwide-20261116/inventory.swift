import Foundation
import SwiftSyntax
import SwiftParser
func callName(_ n: FunctionCallExprSyntax) -> String {
 if let r=n.calledExpression.as(DeclReferenceExprSyntax.self) {return r.baseName.text}
 if let r=n.calledExpression.as(MemberAccessExprSyntax.self) {return r.declName.baseName.text}
 return n.calledExpression.trimmedDescription
}
final class Scan: SyntaxVisitor {
 var records:[[String:Any]]=[]; let path:String; let converter:SourceLocationConverter
 init(path:String, tree:SourceFileSyntax) {self.path=path; self.converter=SourceLocationConverter(fileName:path,tree:tree);super.init(viewMode:.sourceAccurate)}
 override func visit(_ node:FunctionCallExprSyntax)->SyntaxVisitorContinueKind {
  let name=callName(node); guard ["Button","Menu","NavigationLink","Link","ShareLink","EditButton","PasteButton","RenameButton","PhotosPicker","BTCompactMenu","BTCompactMenuAction"].contains(name) else{return .visitChildren}
  var outer=Syntax(node);var mods:[String]=[];var styles:[String]=[]
  while let member=outer.parent?.as(MemberAccessExprSyntax.self),member.base?.id==outer.id, let call=member.parent?.as(FunctionCallExprSyntax.self),call.calledExpression.id==member.id {
   let method=callName(call); mods.append(method)
   if method=="buttonStyle" {styles.append(call.arguments.trimmedDescription)}
   outer=Syntax(call)
  }
  var context:[String]=[]; var inherited:[String]=[]; var owner=""; var parent=outer.parent
  while let p=parent {
   if let call=p.as(FunctionCallExprSyntax.self) {
    let pos=node.positionAfterSkippingLeadingTrivia.utf8Offset
    func contains(_ syntax: Syntax) -> Bool {syntax.position.utf8Offset <= pos && pos < syntax.endPosition.utf8Offset}
    var branch:String?=nil
    if let closure=call.trailingClosure, contains(Syntax(closure)) {branch="content"}
    for extra in call.additionalTrailingClosures where contains(Syntax(extra.closure)) {branch=extra.label.text}
    for argument in call.arguments where argument.expression.is(ClosureExprSyntax.self) && contains(Syntax(argument.expression)) {branch=argument.label?.text ?? "argument"}
    if let branch {
     context.append(callName(call)+":"+branch)
     var ancestor=Syntax(call)
     while let member=ancestor.parent?.as(MemberAccessExprSyntax.self), member.base?.id==ancestor.id, let modifier=member.parent?.as(FunctionCallExprSyntax.self), modifier.calledExpression.id==member.id {
      if callName(modifier)=="buttonStyle" {inherited.append(modifier.arguments.trimmedDescription)}
      ancestor=Syntax(modifier)
     }
    }
   }
   if owner.isEmpty, let binding=p.as(PatternBindingSyntax.self) {owner=binding.pattern.trimmedDescription}
   if owner.isEmpty, let function=p.as(FunctionDeclSyntax.self) {owner=function.name.text}
   parent=p.parent
  }
  let loc=converter.location(for:node.positionAfterSkippingLeadingTrivia)
  records.append(["file":path,"line":loc.line,"kind":name,"owner":owner,"styles":styles,"modifiers":mods,"contexts":context,"inheritedStyles":inherited,"start":node.positionAfterSkippingLeadingTrivia.utf8Offset,"end":node.endPositionBeforeTrailingTrivia.utf8Offset,"outerEnd":outer.endPositionBeforeTrailingTrivia.utf8Offset,"source":outer.trimmedDescription])
  return .visitChildren
 }
}
var records:[[String:Any]]=[];var fileCount=0
for path in CommandLine.arguments.dropFirst() {
 let source=try String(contentsOfFile:path,encoding:.utf8);let tree=Parser.parse(source:source)
 if tree.hasError {fputs("Parse error: \(path)\n",stderr);exit(2)}
 let scan=Scan(path:path,tree:tree);scan.walk(tree);records+=scan.records;fileCount+=1
}
let json=try JSONSerialization.data(withJSONObject:["files":fileCount,"controls":records],options:[.prettyPrinted,.sortedKeys])
FileHandle.standardOutput.write(json)
