//
//  ListCollectionViewLayout.mm
//  CustomListLayout-iOS
//
//  Created by Jinwoo Kim on 12/23/23.
//

#import "ListCollectionViewLayout.hpp"
#import <numeric>
#import <algorithm>

#define kListCollectionViewLayoutEstimantedHeight 44.f

__attribute__((objc_direct_members))
@interface ListCollectionViewLayout () {
    CGSize _collectionViewContentSize;
}
@property (retain, nonatomic) NSMutableArray<UICollectionViewLayoutAttributes *> *cachedAllAttributes;
@property (retain, nonatomic) NSMutableSet<UICollectionViewLayoutAttributes *> *invalidatedAllAttributes;
@end

@implementation ListCollectionViewLayout

+ (Class)invalidationContextClass {
    return UICollectionViewLayoutInvalidationContext.class;
}

- (instancetype)init {
    if (self = [super init]) {
        _cachedAllAttributes = [NSMutableArray<UICollectionViewLayoutAttributes *> new];
        _invalidatedAllAttributes = [NSMutableSet<UICollectionViewLayoutAttributes *> new];
    }
    
    return self;
}

- (void)dealloc {
    [_cachedAllAttributes release];
    [_invalidatedAllAttributes release];
    [super dealloc];
}

- (CGSize)collectionViewContentSize {
    return _collectionViewContentSize;
}

- (void)prepareLayout {
    if (_cachedAllAttributes.count > 0) {
        [super prepareLayout];
        return;
    }
    
    UICollectionView *collectionView = self.collectionView;
    
    if (!collectionView) {
        [_cachedAllAttributes removeAllObjects];
        [super prepareLayout];
        return;
    }
    
    //
    
    NSInteger numberOfSections = collectionView.numberOfSections;
    if (numberOfSections == 0) {
        [super prepareLayout];
        return;
    }
    
    std::vector<NSInteger> sectionIndexes(numberOfSections);
    std::iota(sectionIndexes.begin(), sectionIndexes.end(), 0);
    
    std::for_each(sectionIndexes.cbegin(),
                  sectionIndexes.cend(), 
                  [collectionView, self](NSInteger section) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:NSNotFound inSection:section];
        [self insertCachedAttributesForIndexPath:indexPath];
    });
    
    //
    
//    NSInteger numberOfItemsOfAllSections = std::accumulate(sectionIndexes.cbegin(),
//                                                           sectionIndexes.cend(),
//                                                           0,
//                                                           [collectionView](NSInteger partial, NSInteger section) {
//        NSInteger numberOfItems = [collectionView numberOfItemsInSection:section];
//        return partial + numberOfItems;
//    });
//    
//    auto cachedAllAttributes = [[NSMutableOrderedSet<UICollectionViewLayoutAttributes *> alloc] initWithCapacity:numberOfItemsOfAllSections];
//    auto cachedAllAttributesForSection = [[NSMutableDictionary<NSNumber *, NSMutableOrderedSet<UICollectionViewLayoutAttributes *> *> alloc] initWithCapacity:numberOfSections];
//    
//    CGSize size = collectionView.bounds.size;
//    CGFloat width = size.width;
//    
//    CGFloat totalHeight = std::accumulate(sectionIndexes.cbegin(),
//                                          sectionIndexes.cend(),
//                                          0.f,
//                                          [collectionView, cachedAllAttributes, cachedAllAttributesForSection, width](CGFloat partialHeight, NSInteger section) {
//        NSInteger numberOfItems = [collectionView numberOfItemsInSection:section];
//        
//        if (numberOfItems == 0) {
//            return partialHeight;
//        }
//        
//        auto cachedAttributesForSection = [[NSMutableOrderedSet<UICollectionViewLayoutAttributes *> alloc] initWithCapacity:numberOfItems];
//        std::vector<NSInteger> itemIndexes(numberOfItems);
//        std::iota(itemIndexes.begin(), itemIndexes.end(), 0);
//        
//        CGFloat height = std::accumulate(itemIndexes.cbegin(),
//                                         itemIndexes.cend(),
//                                         partialHeight,
//                                         [section, cachedAllAttributes, cachedAttributesForSection, width](CGFloat partialHeight, NSInteger item) {
//            NSAutoreleasePool *pool = [NSAutoreleasePool new];
//            
//            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
//            UICollectionViewLayoutAttributes *layoutAttributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
//            
//            layoutAttributes.frame = CGRectMake(0.f,
//                                                partialHeight,
//                                                width,
//                                                kListCollectionViewLayoutEstimantedHeight);
//            
//            [cachedAllAttributes addObject:layoutAttributes];
//            [cachedAttributesForSection addObject:layoutAttributes];
//            
//            [pool release];
//            
//            return partialHeight + kListCollectionViewLayoutEstimantedHeight; /* estimated */
//        });
//        
//        cachedAllAttributesForSection[@(section)] = cachedAttributesForSection;
//        [cachedAttributesForSection release];
//        
//        return height;
//    });
//    
//    _collectionViewContentSize = CGSizeMake(size.width, totalHeight + collectionView.safeAreaInsets.bottom);
//    self.cachedAllAttributes = cachedAllAttributes;
//    self.cachedAllAttributesForSection = cachedAllAttributesForSection;
//    
//    [cachedAllAttributes release];
//    [cachedAllAttributesForSection release];
    
    [super prepareLayout];
}

- (void)prepareForCollectionViewUpdates:(NSArray<UICollectionViewUpdateItem *> *)updateItems {
    [updateItems enumerateObjectsUsingBlock:^(UICollectionViewUpdateItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        switch (item.updateAction) {
            case UICollectionUpdateActionInsert:
                [self insertCachedAttributesForIndexPath:item.indexPathAfterUpdate];
                break;
            case UICollectionUpdateActionDelete:
                [self deleteCachedAttributesForIndexPath:item.indexPathBeforeUpdate];
                break;
            case UICollectionUpdateActionReload:
                NSLog(@"Reload - %@ %@", item.indexPathBeforeUpdate, item.indexPathAfterUpdate);
                break;
            case UICollectionUpdateActionMove:
                [self moveCachedAttributesFromIndexPath:item.indexPathBeforeUpdate toIndexPath:item.indexPathAfterUpdate];
                break;
            default:
                break;
        }
    }];
    
    [super prepareForCollectionViewUpdates:updateItems];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    for (UICollectionViewLayoutAttributes *layoutAttributes in _cachedAllAttributes) {
        if ([layoutAttributes.indexPath isEqual:indexPath]) {
            return layoutAttributes;
        }
    }
    
    return nil;
}

- (NSArray<__kindof UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    return _cachedAllAttributes;
}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)itemIndexPath {
    return [self layoutAttributesForItemAtIndexPath:itemIndexPath];
}

- (BOOL)shouldInvalidateLayoutForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes {
    BOOL result = preferredAttributes.frame.size.height != originalAttributes.frame.size.height;
    
    if (result) {
        [_invalidatedAllAttributes addObject:preferredAttributes];
    }
    
    return result;
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes {
    NSUInteger invalidatedCount = _invalidatedAllAttributes.count;
    
    if (invalidatedCount == 0) return nil;
    
    UICollectionViewLayoutInvalidationContext *context = [UICollectionViewLayoutInvalidationContext new];
    
    auto indexPaths = [[NSMutableArray<NSIndexPath *> alloc] initWithCapacity:invalidatedCount];
    
    for (UICollectionViewLayoutAttributes *attributes in _invalidatedAllAttributes) {
        NSIndexPath *indexPath = attributes.indexPath;
        [indexPaths addObject:indexPath];
    }
    
    [context invalidateItemsAtIndexPaths:indexPaths];
    [indexPaths release];
    
    return [context autorelease];
}

- (void)invalidateLayoutWithContext:(UICollectionViewLayoutInvalidationContext *)context {
    NSUInteger invalidatedCount = _invalidatedAllAttributes.count;
    
    if (invalidatedCount) {
        NSUInteger count_cachedAllAttributes = _cachedAllAttributes.count;
        
        for (UICollectionViewLayoutAttributes *attributes in _invalidatedAllAttributes) {
            NSIndexPath *indexPath = attributes.indexPath;
            
            //
            
            UICollectionViewLayoutAttributes *oldAttributes = [self layoutAttributesForItemAtIndexPath:indexPath];
            CGRect oldFrame = oldAttributes.frame;
            CGRect newFrame = attributes.frame;
            oldAttributes.frame = CGRectMake(oldFrame.origin.x,
                                             oldFrame.origin.y,
                                             oldFrame.size.width,
                                             newFrame.size.height);
            
            CGFloat diff = newFrame.size.height - oldFrame.size.height;
            
            NSUInteger index_cachedAllAttributes = [_cachedAllAttributes indexOfObject:oldAttributes];
            
            auto sub_cachedAllAttributes = [_cachedAllAttributes objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index_cachedAllAttributes + 1, count_cachedAllAttributes - index_cachedAllAttributes - 1)]];
            [sub_cachedAllAttributes enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                CGRect frame = obj.frame;
                
                obj.frame = CGRectMake(frame.origin.x,
                                       frame.origin.y + diff,
                                       frame.size.width,
                                       frame.size.height);
            }];
            
            _collectionViewContentSize.height += diff;
        }
        
        [_invalidatedAllAttributes removeAllObjects];
    }
    
    [super invalidateLayoutWithContext:context];
}

- (void)insertCachedAttributesForIndexPath:(NSIndexPath *)indexPath __attribute__((objc_direct)) {
    if (indexPath.item == NSNotFound) {
        NSInteger section = indexPath.section;
        NSInteger numberOfItems = [self.collectionView numberOfItemsInSection:section];
        
        std::vector<NSInteger> itemIndexes(numberOfItems);
        std::iota(itemIndexes.begin(), itemIndexes.end(), 0);
        
        std::for_each(itemIndexes.cbegin(),
                      itemIndexes.cend(),
                      [self, section](NSInteger item) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
            [self _insertCachedAttributesForIndexPath:indexPath];
        });
    } else {
        [self _insertCachedAttributesForIndexPath:indexPath];
    }
}

- (void)_insertCachedAttributesForIndexPath:(NSIndexPath *)indexPath __attribute__((objc_direct)) {
    __block NSInteger targetIndex = NSNotFound;
    NSInteger section = indexPath.section;
    NSInteger item = indexPath.item;
    
    if (section == 0 && item == 0) {
        targetIndex = 0;
    } else {
        [_cachedAllAttributes enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSIndexPath *objIndexPath = obj.indexPath;
            
            if (item == 0) {
                if (objIndexPath.section == section - 1) {
                    targetIndex = idx;
                    *stop = YES;
                }
            } else {
                if (objIndexPath.section == section && objIndexPath.item == item - 1) {
                    targetIndex = idx + 1;
                    *stop = YES;
                }
            }
        }];
    }
    
    assert(targetIndex != NSNotFound);
    
    //
    
    UICollectionViewLayoutAttributes *layoutAttributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    CGFloat y;
    if (targetIndex == 0) {
        y = 0.f;
    } else {
        y = CGRectGetMaxY(_cachedAllAttributes[targetIndex - 1].frame);
    }
    layoutAttributes.frame = CGRectMake(0.f,
                                        y,
                                        self.collectionView.bounds.size.width,
                                        kListCollectionViewLayoutEstimantedHeight);
    
    [_cachedAllAttributes insertObject:layoutAttributes atIndex:targetIndex];
    
    //
    
    NSArray<UICollectionViewLayoutAttributes *> *sub_cachedAllAttributes = [_cachedAllAttributes objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(targetIndex + 1, _cachedAllAttributes.count - targetIndex - 1)]];
    
    [sub_cachedAllAttributes enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSIndexPath *objIndexPath = obj.indexPath;
        NSInteger objSection = objIndexPath.section;
        NSInteger objItem = objIndexPath.item;
        
        if (objSection == section) {
            obj.indexPath = [NSIndexPath indexPathForItem:objItem + 1 inSection:objSection];
        }
        
        CGRect objFrame = obj.frame;
        obj.frame = CGRectMake(objFrame.origin.x,
                               objFrame.origin.y + kListCollectionViewLayoutEstimantedHeight,
                               objFrame.size.width,
                               objFrame.size.height);
        
        _collectionViewContentSize = CGSizeMake(self.collectionView.bounds.size.width,
                                                _collectionViewContentSize.height + kListCollectionViewLayoutEstimantedHeight);
    }];
}

- (void)deleteCachedAttributesForIndexPath:(NSIndexPath *)indexPath __attribute__((objc_direct)) {
    
}

- (void)reloadCachedAttributesForIndexPath:(NSIndexPath *)indexPath __attribute__((objc_direct)) {
    
}

- (void)moveCachedAttributesFromIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath __attribute__((objc_direct)) {
    
}

@end
