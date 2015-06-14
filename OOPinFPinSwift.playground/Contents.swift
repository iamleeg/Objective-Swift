import Cocoa

typealias Selector = String

enum IMP {
  case method((Selector->IMP, Selector, Selector->IMP...)->(Selector->IMP)?)
  case asInteger((Selector->IMP, Selector, Selector->IMP...)->Int?)
  case methodMissing((Selector->IMP, Selector, Selector->IMP...)->(Selector->IMP)?)
  case description((Selector->IMP, Selector, Selector->IMP...)->String?)
}

typealias Object = Selector -> IMP

func DoesNothing()->Object {
  return { _ in
    return IMP.methodMissing({(this, _cmd, args : Object...) in
      assertionFailure("method missing: \(_cmd)")
      return nil
    })
  }
}

let o : Object = DoesNothing()

infix operator .. {}
infix operator .... {}

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

func .... (receiver: Object?, _cmd:Selector) -> IMP? {
  guard let this = receiver else { return nil }
  let method = (this→"superclass")!(_cmd)
  switch(method) {
  case IMP.methodMissing(let f):
    return f(this, _cmd)...._cmd
  default:
    return method
  }
}

infix operator → {}
infix operator →→ {}

func → (receiver: Object?, _cmd:Selector) -> Object? {
  if let imp = receiver.._cmd {
    switch imp {
    case .method(let f):
      return f(receiver!, _cmd)
    default:
      return nil
    }
  } else {
    return nil
  }
}

func →→ (receiver: Object?, _cmd:Selector) -> Object? {
  guard let imp = receiver...._cmd else { return nil }
  switch imp {
  case .method(let f):
    return f(receiver!, _cmd)
  default:
    return nil
  }
}

infix operator ☞ {}

func mutate(receiver: Object, selector: Selector, value:Object) -> Object {
  return { _cmd in
    switch _cmd {
    case selector:
      return .method({ _ in return value })
    default:
      return receiver(_cmd)
    }
  }
}

func ☞(message:(receiver: Object?, selector: Selector), value:Object) -> Object? {
  if let receiver = message.receiver {
    return mutate(receiver, selector: message.selector, value: value)
  } else {
    return nil
  }
}

func ℹ︎(receiver:Object?)->Int? {
  if let imp = receiver.."asInteger" {
    switch imp {
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
  _self = { selector in
    switch selector {
    case "asInteger":
      return IMP.asInteger({ _ in return _x })
    case "description":
      return IMP.description({ _ in return "\(_x)" })
    default:
      return proto(selector)
    }
  }
  return _self
}

func Point(x: Int, y: Int, proto: Object)->((_cmd:Selector)->IMP) {
  let _x = Integer(x,proto: o), _y = Integer(y,proto: o)
  var _self : Object! = nil
  _self = { selector in
    switch selector {
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
        return (this, "y")☞args[0]
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
  return _self
}

func 📓(receiver:Object?) -> String? {
  if let imp = receiver.."description" {
    switch imp {
    case .description(let f):
      return f(receiver!, "description")
    default:
      return nil
    }
  } else {
    return nil
  }
}

let p = Point(3, y: 4, proto: o)
📓(p)
let p2 = (p,"x")☞(Integer(1,proto: o))
📓(p2)

infix operator ✍ {}

func ✍(message:(receiver:Object?, selector:Selector), value:Object) -> Object? {
  if let imp = message.receiver..message.selector {
    switch imp {
    case .method(let f):
      return f(message.receiver!, message.selector, value)
    default:
      return nil
    }
  } else {
    return nil
  }
}

let p3 = (p2, "setY:")✍(Integer(42, proto: o))
📓(p3)

typealias Class = Object

// define a "Non-Standalone" Object that relies on a class for its methods.

let NSObject : Class = { aSelector in
  switch aSelector {
  case "description":
    return IMP.description({ _ in return "An NSObject" })
  case "instanceVariables":
    return IMP.method({ _ in return o })
  case "superclass":
    return .method({ _ in return nil })
  default:
    return IMP.methodMissing({ _ in
      print("Instance does not recognize selector \(aSelector)")
      return nil
    })
  }
}

func newObject(isa : Class) -> Object {
  let ivars = (isa→"instanceVariables")!
  return { aSelector in
    let ivarIMP = ivars(aSelector)
    switch ivarIMP {
    case .method(_):
      return ivarIMP
    default:
      return isa(aSelector)
    }
  }
}

let anObject = newObject(NSObject)
📓(anObject)

func NSPoint(x:Int, y:Int) -> Class {
  let superclass = NSObject
  let ivars:Object = { variableName in
    switch variableName {
    case "x":
      return .method({_ in return Integer(x, proto: o)})
    case "y":
      return .method({_ in return Integer(y, proto: o)})
    default:
      return (superclass→"instanceVariables")!(variableName)
    }
  }
  let thisClass:Class = { aSelector in
    switch aSelector {
    case "instanceVariables":
      return .method({_ in return ivars})
    case "distanceFromOrigin":
      return .method({(this, _cmd, args:Object...) in
        let thisX = ℹ︎(this→"x")!
        let thisY = ℹ︎(this→"y")!
        let distance = sqrt(Double(thisX*thisX + thisY*thisY))
        return Integer(Int(distance), proto: o)
      })
    case "superclass":
      return .method({ _ in return superclass })
    default:
      return superclass(aSelector)
    }
  }
  return thisClass
}

let aPoint = newObject(NSPoint(3,y: 4))
📓(aPoint)
📓(aPoint→"x")
📓(aPoint→"distanceFromOrigin")

func NS3DPoint(x:Int, y:Int, z:Int) -> Class {
  let superclass = NSPoint(x, y: y)
  let ivars:Object = { variableName in
    switch variableName {
    case "z":
      return .method({_ in return Integer(z, proto: o)})
    default:
      return (superclass→"instanceVariables")!(variableName)
    }
  }
  let thisClass:Class = { aSelector in
    switch aSelector {
    case "instanceVariables":
      return .method({_ in return ivars})
    case "distanceFromOrigin":
      return .method({(this, _cmd, args:Object...) in
        let twoDDistance = ℹ︎(this→→"distanceFromOrigin")!
        let thisZ = ℹ︎(this→"z")!
        let distance = sqrt(Double(twoDDistance*twoDDistance + thisZ*thisZ))
        return Integer(Int(distance), proto: o)
      })
    case "superclass":
      return .method({ _ in return superclass })
    default:
      return superclass(aSelector)
    }
  }
  return thisClass
}

let anotherPoint = newObject(NS3DPoint(10, y: 12, z: 14))
📓(anotherPoint→"distanceFromOrigin")

func NoArgsBlock(code:()->Object?, proto:Object)->Object {
  var _self:Object! = nil
  _self = { aSelector in
    switch aSelector {
    case "value":
      return .method({_ in return code()})
    default:
      return proto(aSelector)
    }
  }
  return _self
}

let emptyBlock = NoArgsBlock({ return nil }, proto: o)

func OneArgBlock(code:(Object)->Object?, proto:Object)->Object {
  var _self:Object! = nil
  _self = { aSelector in
    switch aSelector {
    case "value:":
      return .method({(this, _cmd, args:Object...) in
        let arg = args[0]
        return code(arg)
      })
    default:
      return proto(aSelector)
    }
  }
  return _self
}

func NSArray(objects:[Object]) -> Class {
  let superclass = NSObject
  let thisClass:Class = { aSelector in
    switch aSelector {
    case "count":
      return .method({_ in return Integer(objects.count,proto: o)})
    case "filter:":
      return .method({(this, _cmd, args:Object...) in
        let block = args[0]
        var filtered:[Object] = []
        for object in objects {
          let result = (block, "value:") ✍ object
          (result, "ifTrue:") ✍ NoArgsBlock({ filtered.append(object); return object; }, proto: o)
        }
        return NSArray(filtered)
      })
    case "objectAtIndex:":
      return .method({(this, _cmd, args:Object...) in
        let index = ℹ︎(args[0])!
        return objects[index]
      })
    case "superclass":
      return .method({ _ in return superclass })
    default:
      return superclass(aSelector)
    }
  }
  return thisClass
}

func NSArray(objects:Object...) -> Class {
  return NSArray(objects)
}

let NSBoolean : Class = { aSelector in
  let superclass = NSObject
  switch aSelector {
  case "ifFalse:":
    return .method({(this, _cmd, args:Object...) in
      let falseBlock = args[0]
      let maybeBoolIMP = this.."ifTrue:ifFalse:"
      guard let boolIMP = maybeBoolIMP else { return nil }
      switch boolIMP {
      case .method(let f):
        return f(this, "ifTrue:ifFalse:", emptyBlock, falseBlock)
      default:
        return nil
      }
    })
  case "ifTrue:":
    return .method({(this, _cmd, args:Object...) in
      let trueBlock = args[0]
      let maybeBoolIMP = this.."ifTrue:ifFalse:"
      guard let boolIMP = maybeBoolIMP else { return nil }
      switch boolIMP {
      case .method(let f):
        return f(this, "ifTrue:ifFalse:", trueBlock, emptyBlock)
      default:
        return nil
      }
    })
  case "superclass":
    return .method({_ in return superclass })
  default:
    return superclass(aSelector)
  }
}

let NSBooleanFalse : Class = { aSelector in
  let superclass = NSBoolean
  switch aSelector {
  case "description":
    return .description({_ in return "False"})
  case "ifTrue:ifFalse:":
    return .method({(this, _cmd, args:Object...) in
      let falseBlock = args[1]
      return falseBlock→"value"
    })
  case "superclass":
    return .method({_ in return superclass})
  default:
    return superclass(aSelector)
  }
}

let False = newObject(NSBooleanFalse)

let NSBooleanTrue : Class = { aSelector in
  let superclass = NSBoolean
  switch aSelector {
  case "description":
    return .description({_ in return "True"})
  case "ifTrue:ifFalse:":
    return .method({(this, _cmd, args:Object...) in
      let trueBlock = args[0]
      return trueBlock→"value"
    })
  case "superclass":
    return .method({_ in return superclass})
  default:
    return superclass(aSelector)
  }
}

let True = newObject(NSBooleanTrue)

let myArray = newObject(NSArray(Integer(1, proto: o), Integer(2, proto: o),
  Integer(3, proto: o), Integer(4, proto: o)))
let evens = (myArray,"filter:") ✍ OneArgBlock({ obj in
  return (ℹ︎(obj)! % 2) == 0 ? True : False
  }, proto: o)
ℹ︎(evens→"count")
📓((evens,"objectAtIndex:") ✍ Integer(0, proto: o))
📓((evens,"objectAtIndex:") ✍ Integer(1, proto: o))