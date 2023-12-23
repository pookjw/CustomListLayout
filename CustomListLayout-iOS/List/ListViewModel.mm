//
//  ListViewModel.mm
//  CustomListLayout-iOS
//
//  Created by Jinwoo Kim on 12/22/23.
//

#import "ListViewModel.hpp"
#import "NSDiffableDataSourceSnapshot+sort.h"
#import <random>

__attribute__((objc_direct_members))
@interface ListViewModel ()
@property (retain, nonatomic) UICollectionViewDiffableDataSource<NSNumber *, ListItemModel *> *dataSource;
@property (retain, nonatomic) dispatch_queue_t queue;
@end

@implementation ListViewModel

- (instancetype)initWithDataSource:(UICollectionViewDiffableDataSource<NSNumber *,ListItemModel *> *)dataSource {
    if (self = [super init]) {
        _dataSource = [dataSource retain];
        
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, QOS_MIN_RELATIVE_PRIORITY);
        _queue = dispatch_queue_create("ListViewModel", attr);
    }
    
    return self;
}

- (void)dealloc {
    [_dataSource release];
    dispatch_release(_queue);
    [super dealloc];
}

- (void)loadDataSourceWithCompletionHandler:(void (^)())completionHandler {
    auto dataSource = self.dataSource;
    
    dispatch_async(_queue, ^{
        auto snapshot = [NSDiffableDataSourceSnapshot<NSNumber *, ListItemModel *> new];
        
        NSArray<NSNumber *> *sections = @[@0, @1, @2];
        [snapshot appendSectionsWithIdentifiers:sections];
        
        [sections enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            ListItemModel *items[30];
            for (NSUInteger i = 0; i < 30; i++) {
                items[i] = [[[ListItemModel alloc] initWithSection:obj item:@(i)] autorelease];
            }
            NSArray<ListItemModel *> *itemsArray = [NSArray<ListItemModel *> arrayWithObjects:items count:30];
            
            [snapshot appendItemsWithIdentifiers:itemsArray intoSectionWithIdentifier:obj];
        }];
        
        [dataSource applySnapshot:snapshot animatingDifferences:YES completion:completionHandler];
        [snapshot release];
    });
}

- (void)shuffleWithCompletionHandler:(void (^)())completionHandler {
    auto dataSource = self.dataSource;
    
    dispatch_async(_queue, ^{
        auto snapshot = reinterpret_cast<NSDiffableDataSourceSnapshot<NSNumber *, ListItemModel *> *>([dataSource.snapshot copy]);
        
        auto sectionIdentifiers = snapshot.sectionIdentifiers;
        NSUInteger numberOfSections = sectionIdentifiers.count;
        
        if (numberOfSections == 0) {
            [snapshot release];
            return;
        }
        
        __block std::random_device rd;
        __block std::mt19937 gen(rd());
        __block std::bernoulli_distribution bool_dist(0.5);
        __block std::uniform_int_distribution<NSUInteger> numberOfSections_dist(0, numberOfSections - 1);
        
        [sectionIdentifiers enumerateObjectsUsingBlock:^(NSNumber * _Nonnull section, NSUInteger idx, BOOL * _Nonnull stop) {
            auto sectionIdentifiers = snapshot.sectionIdentifiers;
            
            BOOL sectionBefore = bool_dist(gen);
            NSNumber *randomSection = sectionIdentifiers[numberOfSections_dist(gen)];
            while ([section isEqualToNumber:randomSection]) randomSection = sectionIdentifiers[numberOfSections_dist(gen)];
            
            if (sectionBefore) {
                [snapshot moveSectionWithIdentifier:section beforeSectionWithIdentifier:randomSection];
            } else {
                [snapshot moveSectionWithIdentifier:section afterSectionWithIdentifier:randomSection];
            }
            
            auto itemIdentifiers = [snapshot itemIdentifiersInSectionWithIdentifier:section];
            NSUInteger numberOfItems = itemIdentifiers.count;
            
            if (numberOfItems == 0) {
                return;
            }
            
            __block std::uniform_int_distribution<NSUInteger> numberOfItems_dist(0, numberOfItems - 1);
            [itemIdentifiers enumerateObjectsUsingBlock:^(ListItemModel * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
                auto items = [snapshot itemIdentifiersInSectionWithIdentifier:section];
                
                BOOL itemBefore = bool_dist(gen);
                BOOL randomItemIndex = numberOfItems_dist(gen);
                while ([item isEqual:items[randomItemIndex]]) randomItemIndex = numberOfItems_dist(gen);
                
                ListItemModel *randomItem = [snapshot itemIdentifiersInSectionWithIdentifier:section][randomItemIndex];
                
                if (itemBefore) {
                    [snapshot moveItemWithIdentifier:item beforeItemWithIdentifier:randomItem];
                } else {
                    [snapshot moveItemWithIdentifier:item afterItemWithIdentifier:randomItem];
                }
            }];
        }];
        
        [dataSource applySnapshot:snapshot animatingDifferences:YES completion:completionHandler];
        [snapshot release];
    });
}

- (void)sortWithCompletionHandler:(void (^)())completionHandler {
    auto dataSource = self.dataSource;
    
    dispatch_async(_queue, ^{
        auto snapshot = reinterpret_cast<NSDiffableDataSourceSnapshot<NSNumber *, ListItemModel *> *>([dataSource.snapshot copy]);
        
        [snapshot sortSectionsUsingComparator:^NSComparisonResult(NSNumber * _Nonnull obj1, NSNumber * _Nonnull obj2) {
            return [obj1 compare:obj2];
        }];
        
        [snapshot sortItemsWithSectionIdentifiers:snapshot.sectionIdentifiers usingComparator:^NSComparisonResult(ListItemModel * _Nonnull obj1, ListItemModel * _Nonnull obj2) {
            return [obj1.item compare:obj2.item];
        }];
        
        [dataSource applySnapshot:snapshot animatingDifferences:YES completion:completionHandler];
        [snapshot release];
    });
}

- (void)incrementWithCompletionHandler:(void (^ _Nullable)())completionHandler {
    auto dataSource = self.dataSource;
    
    dispatch_async(_queue, ^{
        auto snapshot = reinterpret_cast<NSDiffableDataSourceSnapshot<NSNumber *, ListItemModel *> *>([dataSource.snapshot copy]);
        
        NSUInteger numberOfSections = snapshot.sectionIdentifiers.count;
        
        auto newSections = [NSMutableArray<NSNumber *> new];
        for (NSUInteger i = numberOfSections; i < numberOfSections + 3; i++) {
            [newSections addObject:@(i)];
        }
        [snapshot appendSectionsWithIdentifiers:newSections];
        [newSections release];
        
        [snapshot.sectionIdentifiers enumerateObjectsUsingBlock:^(NSNumber * _Nonnull section, NSUInteger idx, BOOL * _Nonnull stop) {
            NSUInteger count = [snapshot numberOfItemsInSection:section];
            
            auto newItems = [NSMutableArray<ListItemModel *> new];
            for (NSUInteger i = count; i < count + 30; i++) {
                ListItemModel *itemModel = [[ListItemModel alloc] initWithSection:section item:@(i)];
                [newItems addObject:itemModel];
                [itemModel release];
            }
            
            [snapshot appendItemsWithIdentifiers:newItems intoSectionWithIdentifier:section];
            [newItems release];
        }];
        
        [dataSource applySnapshot:snapshot animatingDifferences:YES completion:completionHandler];
        [snapshot release];
    });
}

- (void)decrementWithCompletionHandler:(void (^ _Nullable)())completionHandler {
    auto dataSource = self.dataSource;
    
    dispatch_async(_queue, ^{
        auto snapshot = reinterpret_cast<NSDiffableDataSourceSnapshot<NSNumber *, ListItemModel *> *>([dataSource.snapshot copy]);
        
        auto sections = snapshot.sectionIdentifiers;
        NSUInteger numberOfSections = sections.count;
        if (numberOfSections == 0) {
            [snapshot release];
            return;
        }
        
        auto deletedItems = [NSMutableArray<ListItemModel *> new];
        
        [sections enumerateObjectsUsingBlock:^(NSNumber * _Nonnull section, NSUInteger idx, BOOL * _Nonnull stop) {
            auto items = [snapshot itemIdentifiersInSectionWithIdentifier:section];
            NSUInteger lastIndex = items.count - 1;
            
            for (NSUInteger i = 0; i < 30; i++) {
                NSUInteger target = (lastIndex - i);
                NSNumber *targetNumbder = @(target);
                
                [items enumerateObjectsUsingBlock:^(ListItemModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if ([obj.item isEqualToNumber:targetNumbder]) {
                        [deletedItems addObject:obj];
                        *stop = YES;
                    }
                }];
            }
        }];
        
        [snapshot deleteItemsWithIdentifiers:deletedItems];
        [deletedItems release];
        
        auto deletedSections = [NSMutableArray<NSNumber *> new];
        
        [sections enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSUInteger count = [snapshot numberOfItemsInSection:obj];
            
            if (count == 0) {
                [deletedSections addObject:obj];
            }
        }];
        [snapshot deleteSectionsWithIdentifiers:deletedSections];
        [deletedSections release];
        
        [dataSource applySnapshot:snapshot animatingDifferences:YES completion:completionHandler];
        [snapshot release];
    });
}

@end
