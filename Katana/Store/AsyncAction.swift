//
//  AsyncAction.swift
//  Katana
//
//  Copyright © 2016 Bending Spoons.
//  Distributed under the MIT License.
//  See the LICENSE file for more information.

import Foundation

/// This enum represents the state of an `AsyncAction`
public enum AsyncActionState {
  /// The action has just been created
  case loading
  
  /// The action's related operation has been completed
  case completed
  
  /// The action's related operation has failed
  case failed
}

/**
 Protocol that represents an `async` action.
 
 An `AsyncAction` is just an abstraction over `Action` that provides a way to structure
 your action.
 
 You typically use an `Async` action when you have to deal with operations that are asynchronous.
 In the most common scenario, you dispatch the initial action, execute an operation in the side effect 
 and then dispatch a completed/failed action based on the result of the operation.
 
 This protocol offers two main advantages:

 * The way in which the action payloads are defined is enforced. We introduced this pattern to
   allow future automatic behaviours such as automatic serialization/deserialization of the actions
   (that can be used for debugging, time travel and so on)
 
 * Convenient separation of the updateStae function based on the state of the action
   (`updatedStateForLoading(currentState: action:)`, `updatedStateForCompleted(currentState: action:)`
    and `updatedStateForFailed(currentState: action:)`)
 
 It is important to note that this is just a a convenience approach to something you can do anyway.
 You can for instance create three actions: `performOperation`, `OperationCompleted` and `OperationFailed` and achieve
 the same result. `AsyncAction` just provide a way to abstract and simplify the process
 
 #### Tip & Tricks
 Since the `Action` protocol is very generic when it comes to the state type that should be updated, a pattern
 we want to promote is to put in your application a protocol like the following:
 
 ```
 protocol AppSyncAction: AsyncAction {
  static func updatedStateForLoading(currentState: inout AppState, action: AddTodo)
  // same for completed and failed
 }
 
 extension AppSyncAction {
  static func updatedStateForLoading(currentState: State, action: AddTodo) -> State {
    guard var state = state as? AppState else {
      fatalError("Something went wrong")
    }
 
    self.updatedStateForLoading(currentState: &state, action: action)
    return state
  }
 
  // same for completed and failed
 }
 ```
 
 In this way you can save a lot of code since you can use your actions in the following way
 
 ```
 struct A: AppAsyncAction {
  static func updatedStateForLoading(currentState: inout AppState, action: AddTodo) {
    state.props = action.payload
  }
 
  // same for completed and failed
 }
 ```
*/
public protocol AsyncAction: Action {
  
  /// The type of payload when the state is `loading`
  associatedtype LoadingPayload
  
  /// The type of payload when the state is `completed`
  associatedtype CompletedPayload
  
  /// The type of payload when the state is `failed`
  associatedtype FailedPayload
  
  /// The state of the action
  var state: AsyncActionState { get set }
  
  /// The loading payload of the action
  var loadingPayload: LoadingPayload { get set }
  
  /// The completed payload of the action. It has a value only when the state is `completed`
  var completedPayload: CompletedPayload? { get set }
  
  /// The failed payload of the action. It has a value only when the state is `failed`
  var failedPayload: FailedPayload? { get set }
  
  /**
   UpdateState function that will be used when the state of the action is `loading`
   
   - parameter state:   the current state of the application
   - parameter action:  the action. The state of the action is `loading`
   - returns: the new state
  */
  static func updatedStateForLoading(currentState: State, action: Self) -> State

  /**
   UpdateState function that will be used when the state of the action is `completed`
   
   - parameter state:   the current state of the application
   - parameter action:  the action. The state of the action is `completed`
   - returns: the new state
  */
  static func updatedStateForCompleted(currentState: State, action: Self) -> State

  /**
   UpdateState function that will be used when the state of the action is `failed`
   
   - parameter state:   the current state of the application
   - parameter action:  the action. The state of the action is `failed`
   - returns: the new state
  */
  static func updatedStateForFailed(currentState: State, action: Self) -> State
  
  /**
   Creates a new action
   
   - parameter payload: the payload to assign to the action
   - returns: an instance of the action where the state must be `loading`
  */
  init(payload: LoadingPayload)
  
  /**
   Creates a new action in the `completed` state
   
   - parameter payload: the payload of the completed action
   - returns: a new instance of the action, where the state is `completed`.
              This new action will have the loading payload inerithed from the initial
              loading action and the provided completed payload
  */
  func completedAction(payload: CompletedPayload) -> Self
  
  /**
   Creates a new action in the `failed` state
   
   - parameter payload: the payload of the failed action
   - returns: a new instance of the action, where the state is `failed`.
              This new action will have the loading payload inerithed from the initial
              loading action and the provided failed payload
  */
  func failedAction(payload: FailedPayload) -> Self
}

public extension AsyncAction {
  /**
   Creates a new state starting from the current state and the dispatched action.
   `AsyncAction` implements a default behaviour that invokes 
   `updatedStateForLoading(currentState: action:)`, `updatedStateForCompleted(currentState: action:)`
   or `updatedStateForFailed(currentState: action:)` based on the action's state
   
   - parameter state:  the current state
   - parameter action: the action that has been dispatched
   - returns: the new state
  */
  public static func updatedState(currentState: State, action: Self) -> State {
    switch action.state {
    case .loading:
      return self.updatedStateForLoading(currentState: currentState, action: action)
      
    case .completed:
      return self.updatedStateForCompleted(currentState: currentState, action: action)
      
    case .failed:
      return self.updatedStateForFailed(currentState: currentState, action: action)
    }
  }
  
  /**
   Creates a new action in the `completed` state
   
   - parameter payload: the payload of the completed action
   - returns: a new instance of the action, where the state is `completed`.
   This new action will have the loading payload inerithed from the initial
   loading action and the provided completed payload
  */
  public func completedAction(payload: CompletedPayload) -> Self {
    var copy = self
    copy.completedPayload = payload
    copy.state = .completed
    return copy
  }

  /**
   Creates a new action in the `failed` state
   
   - parameter payload: the payload of the failed action
   - returns: a new instance of the action, where the state is `failed`.
   This new action will have the loading payload inerithed from the initial
   loading action and the provided failed payload
  */
  public func failedAction(payload: FailedPayload) -> Self {
    var copy = self
    copy.failedPayload = payload
    copy.state = .failed
    return copy
  }
}

public extension AsyncAction where Self: ActionWithSideEffect {
  /**
   Implementation of the `ActionWithSideEffect` type erasure.
   We don't invoke the side effect if the state of the action is not loading.
   This is because we want to trigger side effects only during the loading phase.
  */
  static func anySideEffect(action: AnyAction,
                            state: State,
                            dispatch: @escaping StoreDispatch,
                            dependencies: SideEffectDependencyContainer) {
    
    guard let action = action as? Self else {
      preconditionFailure("Action side effect invoked with a wrong 'action' parameter")
    }
    
    if case .loading = action.state {
      self.sideEffect(action: action, state: state, dispatch: dispatch, dependencies: dependencies)
    }
  }
}
