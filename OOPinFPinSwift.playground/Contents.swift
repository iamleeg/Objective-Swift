import Cocoa

typealias Selector = String

enum IMP {
  case method((Selector->IMP, Selector, Selector->IMP...)->((Selector->IMP)?))
  case asInteger((Selector->IMP, Selector, Selector->IMP...)->Int?)
  case methodMissing((Selector->IMP, Selector, Selector->IMP...)->(Selector->IMP)?)
  case description((Selector->IMP, Selector, Selector->IMP...)->String?)
}

typealias Object = Selector -> IMP

func DoesNothing()->Object {
  var _self : Object! = nil
  func myself (selector: Selector)->IMP {
    return IMP.methodMissing({(this, _cmd, args : Object...) in
      assertionFailure("method missing: \(_cmd)")
      return nil
    })
  }
  _self = myself
  return _self
}

let o : Object = DoesNothing()

infix operator .. {}

func .. (receiver: Object?, _cmd:Selector) -> IMP? {
  if let this = receiver {
    let method = this(_cmd)
    switch(method) {
    case .methodMissing(let f):
      return f(this, _cmd).._cmd
    default:
      return method
    }
  }
  else {
    return nil
  }
}

infix operator → {}

func → (receiver: Object?, _cmd:Selector) -> Object? {
  if let imp = receiver.._cmd {
    switch (imp) {
    case .method(let f):
      return f(receiver!, _cmd)
    default:
      return nil
    }
  } else {
    return nil
  }
}

func mutate(object: Object, key: Selector, newValue: Object) -> Object {
  var this : Object! = nil
  this = { _cmd in
    switch (_cmd) {
    case key:
      return .method({ _ in return newValue })
    default:
      return object(_cmd)
    }
  }
  return this
}

infix operator ☞ {}

func ☞(tuple:(receiver: Object?, command: Selector), value:Object) -> Object? {
  if let receiver = tuple.receiver {
    return mutate(receiver, tuple.command, value)
  } else {
    return nil
  }
}

func ℹ︎(receiver:Object?)->Int? {
  if let imp = receiver.."asInteger" {
    switch(imp) {
    case .asInteger(let f):
      return f(receiver!, "asInteger")
    default:
      return nil
    }
  } else {
    return nil
  }
}

func Integer(x: Int, proto: Object) -> Object {
  var _self : Object! = nil
  let _x = x
  func myself(selector:Selector) -> IMP {
    switch(selector) {
    case "asInteger":
      return IMP.asInteger({ _ in return _x })
    case "description":
      return IMP.description({ _ in return "\(_x)" })
    default:
      return proto(selector)
    }
  }
  _self = myself
  return _self
}

func Point(x: Int, y: Int, proto: Object)->((_cmd:Selector)->IMP) {
  var _self : Object! = nil
  var _x = Integer(x,o), _y = Integer(y,o)
  func myself (selector:Selector) -> IMP {
    switch (selector) {
    case "x":
      return IMP.method({ _ in
        return _x
      })
    case "y":
      return IMP.method({ _ in
        return _y
      })
    case "setY:":
      return IMP.method({ (this, aSelector, args : Object...) in
        return mutate(_self, "y", args[0])
      })
    case "description":
      return IMP.description({ (this, aSelector, args : Object...) in
        let xii = ℹ︎(this→"x")!
        let yii = ℹ︎(this→"y")!
        return "(\(xii),\(yii))"
      })
    default:
      return proto(selector)
    }
  }
  _self = myself
  return _self
}

func 📓(receiver:Object?) -> String? {
  if let imp = receiver.."description" {
    switch(imp) {
    case .description(let f):
      return f(receiver!, "description")
    default:
      return nil
    }
  } else {
    return nil
  }
}

let p = Point(3, 4, o)
📓(p)
ℹ︎(p→"x")
let pp = (p,"x")☞(Integer(1,o))
ℹ︎(pp→"x")
📓(pp)
