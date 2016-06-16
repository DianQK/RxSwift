//
//  UICollectionView+Rx.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 4/2/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(iOS) || os(tvOS)

import Foundation
#if !RX_NO_MODULE
import RxSwift
#endif
import UIKit

// Items

extension UICollectionView {
    
    /**
    Binds sequences of elements to collection view items.
    
    - parameter source: Observable sequence of items.
    - parameter cellFactory: Transform between sequence elements and view cells.
    - returns: Disposable object that can be used to unbind.
    */
    public func rx_itemsWithCellFactory<S: Sequence, O: ObservableType where O.E == S>
        (source: O)
        -> (cellFactory: (UICollectionView, Int, S.Iterator.Element) -> UICollectionViewCell)
        -> Disposable {
        return { cellFactory in
            let dataSource = RxCollectionViewReactiveArrayDataSourceSequenceWrapper<S>(cellFactory: cellFactory)
            return self.rx_itemsWithDataSource(dataSource: dataSource)(source: source)
        }
        
    }
    
    /**
    Binds sequences of elements to collection view items.
    
    - parameter cellIdentifier: Identifier used to dequeue cells.
    - parameter source: Observable sequence of items.
    - parameter configureCell: Transform between sequence elements and view cells.
    - parameter cellType: Type of table view cell.
    - returns: Disposable object that can be used to unbind.
    */
    public func rx_itemsWithCellIdentifier<S: Sequence, Cell: UICollectionViewCell, O : ObservableType where O.E == S>
        (cellIdentifier: String, cellType: Cell.Type = Cell.self)
        -> (source: O)
        -> (configureCell: (Int, S.Iterator.Element, Cell) -> Void)
        -> Disposable {
        return { source in
            return { configureCell in
                let dataSource = RxCollectionViewReactiveArrayDataSourceSequenceWrapper<S> { (cv, i, item) in
                    let indexPath = IndexPath(item: i, section: 0)
                    let cell = cv.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! Cell
                    configureCell(i, item, cell)
                    return cell
                }
                    
                return self.rx_itemsWithDataSource(dataSource: dataSource)(source: source)
            }
        }
    }
    
    /**
    Binds sequences of elements to collection view items using a custom reactive data used to perform the transformation.
    
    - parameter dataSource: Data source used to transform elements to view cells.
    - parameter source: Observable sequence of items.
    - returns: Disposable object that can be used to unbind.
    */
    public func rx_itemsWithDataSource<DataSource: protocol<RxCollectionViewDataSourceType, UICollectionViewDataSource>, S: Sequence, O: ObservableType where DataSource.Element == S, O.E == S>
        (dataSource: DataSource)
        -> (source: O)
        -> Disposable  {
        return { source in
            return source.subscribeProxyDataSourceForObject(object: self, dataSource: dataSource, retainDataSource: false) { [weak self] (_: RxCollectionViewDataSourceProxy, event) -> Void in
                guard let collectionView = self else {
                    return
                }
                dataSource.collectionView(collectionView, observedEvent: event)
            }
        }
    }
}

extension UICollectionView {
   
    /**
    Factory method that enables subclasses to implement their own `rx_delegate`.
    
    - returns: Instance of delegate proxy that wraps `delegate`.
    */
    public override func rx_createDelegateProxy() -> RxScrollViewDelegateProxy {
        return RxCollectionViewDelegateProxy(parentObject: self)
    }

    /**
    Factory method that enables subclasses to implement their own `rx_dataSource`.
    
    - returns: Instance of delegate proxy that wraps `dataSource`.
    */
    public func rx_createDataSourceProxy() -> RxCollectionViewDataSourceProxy {
        return RxCollectionViewDataSourceProxy(parentObject: self)
    }
    
    /**
    Reactive wrapper for `dataSource`.
    
    For more information take a look at `DelegateProxyType` protocol documentation.
    */
    public var rx_dataSource: DelegateProxy {
        return proxyForObject(RxCollectionViewDataSourceProxy.self, self)
    }
    
    /**
    Installs data source as forwarding delegate on `rx_dataSource`. 
    
    It enables using normal delegate mechanism with reactive delegate mechanism.
    
    - parameter dataSource: Data source object.
    - returns: Disposable object that can be used to unbind the data source.
    */
    public func rx_setDataSource(dataSource: UICollectionViewDataSource)
        -> Disposable {
        let proxy = proxyForObject(RxCollectionViewDataSourceProxy.self, self)
        return installDelegate(proxy: proxy, delegate: dataSource, retainDelegate: false, onProxyForObject: self)
    }
   
    /**
    Reactive wrapper for `delegate` message `collectionView:didSelectItemAtIndexPath:`.
    */
    public var rx_itemSelected: ControlEvent<IndexPath> {
        let source = rx_delegate.observe(selector: #selector(UICollectionViewDelegate.collectionView(_:didSelectItemAt:)))
            .map { a in
                return a[1] as! IndexPath
            }
        
        return ControlEvent(events: source)
    }

    /**
     Reactive wrapper for `delegate` message `collectionView:didSelectItemAtIndexPath:`.
     */
    public var rx_itemDeselected: ControlEvent<IndexPath> {
        let source = rx_delegate.observe(selector: #selector(UICollectionViewDelegate.collectionView(_:didDeselectItemAt:)))
            .map { a in
                return a[1] as! IndexPath
        }

        return ControlEvent(events: source)
    }

    /**
    Reactive wrapper for `delegate` message `collectionView:didSelectItemAtIndexPath:`.

    It can be only used when one of the `rx_itemsWith*` methods is used to bind observable sequence,
    or any other data source conforming to `SectionedViewDataSourceType` protocol.
    
     ```
         collectionView.rx_modelSelected(MyModel.self)
            .map { ...
     ```
    */
    public func rx_modelSelected<T>(modelType: T.Type) -> ControlEvent<T> {
        let source: Observable<T> = rx_itemSelected.flatMap { [weak self] indexPath -> Observable<T> in
            guard let view = self else {
                return Observable.empty()
            }

            return Observable.just(try view.rx_modelAt(indexPath: indexPath))
        }
        
        return ControlEvent(events: source)
    }

    /**
     Reactive wrapper for `delegate` message `collectionView:didSelectItemAtIndexPath:`.

     It can be only used when one of the `rx_itemsWith*` methods is used to bind observable sequence,
     or any other data source conforming to `SectionedViewDataSourceType` protocol.

     ```
         collectionView.rx_modelDeselected(MyModel.self)
            .map { ...
     ```
     */
    public func rx_modelDeselected<T>(modelType: T.Type) -> ControlEvent<T> {
        let source: Observable<T> = rx_itemDeselected.flatMap { [weak self] indexPath -> Observable<T> in
            guard let view = self else {
                return Observable.empty()
            }

            return Observable.just(try view.rx_modelAt(indexPath: indexPath))
        }

        return ControlEvent(events: source)
    }
    
    /**
    Syncronous helper method for retrieving a model at indexPath through a reactive data source
    */
    public func rx_modelAt<T>(indexPath: IndexPath) throws -> T {
        let dataSource: SectionedViewDataSourceType = castOrFatalError(self.rx_dataSource.forwardToDelegate(), message: "This method only works in case one of the `rx_itemsWith*` methods was used.")
        
        let element = try dataSource.modelAt(indexPath: indexPath)

        return element as! T
    }
}
#endif

#if os(tvOS)

extension UICollectionView {
    
    /**
     Reactive wrapper for `delegate` message `collectionView:didUpdateFocusInContext:withAnimationCoordinator:`.
     */
    public var rx_didUpdateFocusInContextWithAnimationCoordinator: ControlEvent<(context: UIFocusUpdateContext, animationCoordinator: UIFocusAnimationCoordinator)> {
        
        let source = rx_delegate.observe(#selector(UICollectionViewDelegate.collectionView(_:didUpdateFocusInContext:withAnimationCoordinator:)))
            .map { a -> (context: UIFocusUpdateContext, animationCoordinator: UIFocusAnimationCoordinator) in
                let context = a[1] as! UIFocusUpdateContext
                let animationCoordinator = a[2] as! UIFocusAnimationCoordinator
                return (context: context, animationCoordinator: animationCoordinator)
        }

        return ControlEvent(events: source)
    }
}
#endif
