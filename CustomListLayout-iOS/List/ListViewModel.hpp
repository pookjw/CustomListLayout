//
//  ListViewModel.hpp
//  CustomListLayout-iOS
//
//  Created by Jinwoo Kim on 12/22/23.
//

#import <UIKit/UIKit.h>
#import "ListItemModel.hpp"

NS_ASSUME_NONNULL_BEGIN

__attribute__((objc_direct_members))
@interface ListViewModel : NSObject
@property (retain, readonly, nonatomic) UICollectionViewDiffableDataSource<NSNumber *, ListItemModel *> *dataSource;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDataSource:(UICollectionViewDiffableDataSource<NSNumber *, ListItemModel *> *)dataSource NS_DESIGNATED_INITIALIZER;
- (void)loadDataSourceWithCompletionHandler:(void (^ _Nullable)())completionHandler;
- (void)shuffleWithCompletionHandler:(void (^ _Nullable)())completionHandler;
- (void)sortWithCompletionHandler:(void (^ _Nullable)())completionHandler;
- (void)incrementWithCompletionHandler:(void (^ _Nullable)())completionHandler;
- (void)decrementWithCompletionHandler:(void (^ _Nullable)())completionHandler;
@end

NS_ASSUME_NONNULL_END
