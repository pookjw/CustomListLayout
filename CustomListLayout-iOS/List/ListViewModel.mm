//
//  ListViewModel.mm
//  CustomListLayout-iOS
//
//  Created by Jinwoo Kim on 12/22/23.
//

#import "ListViewModel.hpp"
#import <random>

__attribute__((objc_direct_members))
@interface ListViewModel ()
@property (retain, nonatomic) UICollectionViewDiffableDataSource<NSNumber *, NSString *> *dataSource;
@property (retain, nonatomic) dispatch_queue_t queue;
@end

@implementation ListViewModel

- (instancetype)initWithDataSource:(UICollectionViewDiffableDataSource<NSNumber *,NSString *> *)dataSource {
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
        auto snapshot = [NSDiffableDataSourceSnapshot<NSNumber *, NSString *> new];
        
        NSArray<NSNumber *> *sections = @[@0, @1, @2];
        [snapshot appendSectionsWithIdentifiers:sections];
        
        [sections enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *strings[30];
            for (int i = 0; i < 30; i++) {
                strings[i] = [NSString stringWithFormat:@"%@ - %d", obj, i];
            }
            NSArray<NSString *> *items = [NSArray<NSString *> arrayWithObjects:strings count:30];
            
            [snapshot appendItemsWithIdentifiers:items intoSectionWithIdentifier:obj];
        }];
        
        [dataSource applySnapshot:snapshot animatingDifferences:YES completion:completionHandler];
        [snapshot release];
    });
}

- (void)shuffleWithCompletionHandler:(void (^)())completionHandler {
    auto dataSource = self.dataSource;
    
    dispatch_async(_queue, ^{
        auto snapshot = reinterpret_cast<NSDiffableDataSourceSnapshot<NSNumber *, NSString *> *>([dataSource.snapshot copy]);
        
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
            [itemIdentifiers enumerateObjectsUsingBlock:^(NSString * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
                auto items = [snapshot itemIdentifiersInSectionWithIdentifier:section];
                
                BOOL itemBefore = bool_dist(gen);
                BOOL randomItemIndex = numberOfItems_dist(gen);
                while ([item isEqualToString:items[randomItemIndex]]) randomItemIndex = numberOfItems_dist(gen);
                
                NSString *randomItem = [snapshot itemIdentifiersInSectionWithIdentifier:section][randomItemIndex];
                
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

- (void)incrementWithCompletionHandler:(void (^ _Nullable)())completionHandler {
    auto dataSource = self.dataSource;
    
    dispatch_async(_queue, ^{
        auto snapshot = reinterpret_cast<NSDiffableDataSourceSnapshot<NSNumber *, NSString *> *>([dataSource.snapshot copy]);
        
        auto sectionIdentifiers = snapshot.sectionIdentifiers;
        NSUInteger numberOfSections = sectionIdentifiers.count;
        
        if (numberOfSections == 0) {
            [snapshot release];
            return;
        }
        
        
    });
}

- (void)decrementWithCompletionHandler:(void (^ _Nullable)())completionHandler {
    auto dataSource = self.dataSource;
    
    dispatch_async(_queue, ^{
        
    });
}

@end
