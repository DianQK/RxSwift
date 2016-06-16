//
//  ConcurrentDispatchQueueScheduler.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 7/5/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

/**
Abstracts the work that needs to be performed on a specific `dispatch_queue_t`. You can also pass a serial dispatch queue, it shouldn't cause any problems.

This scheduler is suitable when some work needs to be performed in background.
*/
public class ConcurrentDispatchQueueScheduler: SchedulerType {
    public typealias Time = NSDate
    
    private let _queue : DispatchQueue
    
    public var now : NSDate {
        return NSDate()
    }
    
    // leeway for scheduling timers
    private var _leeway: Int64 = 0
    
    /**
    Constructs new `ConcurrentDispatchQueueScheduler` that wraps `queue`.
    
    - parameter queue: Target dispatch queue.
    */
    public init(queue: DispatchQueue) {
        _queue = queue
    }
    
    /**
     Convenience init for scheduler that wraps one of the global concurrent dispatch queues.
     
     - parameter globalConcurrentQueueQOS: Target global dispatch queue, by quality of service class.
     */
    @available(iOS 8, OSX 10.10, *)
    public convenience init(globalConcurrentQueueQOS: DispatchQueueSchedulerQOS) {
        let priority = globalConcurrentQueueQOS.QOSClass
        self.init(queue: DispatchQueue.global(attributes: DispatchQueue.GlobalAttributes(rawValue: UInt64(Int(UInt32(priority.rawValue))))))
    }

    
    class func convertTimeIntervalToDispatchInterval(timeInterval: TimeInterval) -> Int64 {
        return Int64(timeInterval * Double(NSEC_PER_SEC))
    }
    
    class func convertTimeIntervalToDispatchTime(timeInterval: TimeInterval) -> DispatchTime {
        return DispatchTime.now()
//        return DispatchTime.now(dispatch_time_t(DISPATCH_TIME_NOW), convertTimeIntervalToDispatchInterval(timeInterval: timeInterval))
    }
    
    /**
    Schedules an action to be executed immediatelly.
    
    - parameter state: State passed to the action to be executed.
    - parameter action: Action to be executed.
    - returns: The disposable object used to cancel the scheduled action (best effort).
    */
    public final func schedule<StateType>(state: StateType, action: (StateType) -> Disposable) -> Disposable {
        return self.scheduleInternal(state: state, action: action)
    }
    
    func scheduleInternal<StateType>(state: StateType, action: (StateType) -> Disposable) -> Disposable {
        let cancel = SingleAssignmentDisposable()
        
        _queue.asynchronously() {
            if cancel.disposed {
                return
            }
            
            cancel.disposable = action(state)
        }
        
        return cancel
    }
    
    /**
    Schedules an action to be executed.
    
    - parameter state: State passed to the action to be executed.
    - parameter dueTime: Relative time after which to execute the action.
    - parameter action: Action to be executed.
    - returns: The disposable object used to cancel the scheduled action (best effort).
    */
    public final func scheduleRelative<StateType>(state: StateType, dueTime: TimeInterval, action: (StateType) -> Disposable) -> Disposable {
        
        // Swift 3.0 IUO
        let timer = DispatchSource.timer(flags: DispatchSource.TimerFlags(rawValue: UInt(0)), queue: _queue)//dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue)!
        
        let dispatchInterval = MainScheduler.convertTimeIntervalToDispatchTime(timeInterval: dueTime)
        
        let compositeDisposable = CompositeDisposable()
//        dispatch_source_set_timer(timer, dispatchInterval, DISPATCH_TIME_FOREVER, 0)
        timer.setEventHandler { 
            if compositeDisposable.disposed {
                return
            }
            compositeDisposable.addDisposable(disposable: action(state))
        }
        timer.resume()
        
        compositeDisposable.addDisposable(disposable: AnonymousDisposable {
            timer.cancel()
            })
        
        return compositeDisposable
    }
    
    /**
    Schedules a periodic piece of work.
    
    - parameter state: State passed to the action to be executed.
    - parameter startAfter: Period after which initial work should be run.
    - parameter period: Period for running the work periodically.
    - parameter action: Action to be executed.
    - returns: The disposable object used to cancel the scheduled action (best effort).
    */
    public func schedulePeriodic<StateType>(state: StateType, startAfter: TimeInterval, period: TimeInterval, action: (StateType) -> StateType) -> Disposable {
        
        // Swift 3.0 IUO
        let timer = DispatchSource.timer(flags: DispatchSource.TimerFlags(rawValue: UInt(0)), queue: _queue)
        
        let initial = MainScheduler.convertTimeIntervalToDispatchTime(timeInterval: startAfter)
        let dispatchInterval = MainScheduler.convertTimeIntervalToDispatchInterval(timeInterval: period)
        
        var timerState = state
        
        let validDispatchInterval = dispatchInterval < 0 ? 0 : Int(dispatchInterval)
        
//        timer.setTimer(start: initial, interval: DispatchTimeInterval.seconds(validDispatchInterval))
        let cancel = AnonymousDisposable {
            timer.cancel()
        }
        timer.setEventHandler { 
            if cancel.disposed {
                return
            }
            timerState = action(timerState)
        }
        timer.resume()
        
        return cancel
    }
}
