//
//  ListCollectionViewLayout.mm
//  CustomListLayout-iOS
//
//  Created by Jinwoo Kim on 12/23/23.
//

#import "ListCollectionViewLayout.hpp"
#import <objc/runtime.h>
#import <numeric>
#import <algorithm>

#define kListCollectionViewLayoutEstimantedHeight 44.f

const void *preferredAttributesArrayKey = &preferredAttributesArrayKey;

__attribute__((objc_direct_members))
@interface ListCollectionViewLayout () {
    CGSize _collectionViewContentSize;
}
@property (retain, nonatomic) NSMutableArray<NSMutableArray<UICollectionViewLayoutAttributes *> *> *cachedAllAttributes;
@property (assign, readonly, nonatomic) NSArray<UICollectionViewLayoutAttributes *> *allCachedAllAttributes;
@end

@implementation ListCollectionViewLayout

+ (Class)invalidationContextClass {
    return UICollectionViewLayoutInvalidationContext.class;
}

+ (Class)layoutAttributesClass {
    return UICollectionViewLayoutAttributes.class;
}

- (instancetype)init {
    if (self = [super init]) {
        _cachedAllAttributes = [NSMutableArray<NSMutableArray<UICollectionViewLayoutAttributes *> *> new];
    }
    
    return self;
}

- (void)dealloc {
    [_cachedAllAttributes release];
    [super dealloc];
}

- (CGSize)collectionViewContentSize {
    return _collectionViewContentSize;
}

- (NSArray<UICollectionViewLayoutAttributes *> *)allCachedAllAttributes {
    auto result = [NSMutableArray<UICollectionViewLayoutAttributes *> new];
    
    for (NSMutableArray<UICollectionViewLayoutAttributes *> *partial in _cachedAllAttributes) {
        [result addObjectsFromArray:partial];
    }
    
    return [result autorelease];
}

- (void)prepareLayout {
    if (_cachedAllAttributes.count > 0) {
        [super prepareLayout];
        return;
    }
    
    if (self.collectionView == nil) {
        [_cachedAllAttributes removeAllObjects];
        [super prepareLayout];
        return;
    }
    
    //
    
    // TODO
    
    [super prepareLayout];
}

- (void)prepareForCollectionViewUpdates:(NSArray<UICollectionViewUpdateItem *> *)updateItems {
    NSLog(@"%@", updateItems);
    
    auto deletedIndexPaths = [NSMutableArray<NSIndexPath *> new];
    auto deletedSections = [NSMutableIndexSet new];
    
    auto insertedSections = [NSMutableIndexSet new];
    auto insertedIndexPaths = [NSMutableArray<NSIndexPath *> new];
    
    // key: before, value: after
    auto movedSections = [NSMutableDictionary<NSNumber *, NSNumber *> new];
    auto movedIndexPaths = [NSMutableArray<UICollectionViewUpdateItem *> new];
    
    auto reloadedSections = [NSMutableIndexSet new];
    auto reloadedIndexPaths = [NSMutableArray<NSIndexPath *> new];
    
    [updateItems enumerateObjectsUsingBlock:^(UICollectionViewUpdateItem * _Nonnull updateItem, NSUInteger idx, BOOL * _Nonnull stop) {
        switch (updateItem.updateAction) {
            case UICollectionUpdateActionInsert:
                if (updateItem.indexPathAfterUpdate.item == NSNotFound) {
                    if ([deletedSections containsIndex:updateItem.indexPathAfterUpdate.section]) {
                        [deletedSections removeIndex:updateItem.indexPathAfterUpdate.section];
                    } else {
                        [insertedSections addIndex:updateItem.indexPathAfterUpdate.section];
                    }
                } else {
                    if ([deletedIndexPaths containsObject:updateItem.indexPathAfterUpdate]) {
                        [deletedIndexPaths removeObject:updateItem.indexPathAfterUpdate];
                    } else {
                        [insertedIndexPaths addObject:updateItem.indexPathAfterUpdate];
                    }
                }
                break;
            case UICollectionUpdateActionDelete:
                if (updateItem.indexPathBeforeUpdate.item == NSNotFound) {
                    if ([insertedSections containsIndex:updateItem.indexPathBeforeUpdate.section]) {
                        [insertedSections removeIndex:updateItem.indexPathBeforeUpdate.section];
                    } else {
                        [deletedSections addIndex:updateItem.indexPathBeforeUpdate.section];
                    }
                } else {
                    if ([insertedIndexPaths containsObject:updateItem.indexPathBeforeUpdate]) {
                        [insertedIndexPaths removeObject:updateItem.indexPathBeforeUpdate];
                    } else {
                        [deletedIndexPaths addObject:updateItem.indexPathBeforeUpdate];
                    }
                }
                break;
            case UICollectionUpdateActionReload:
                if (updateItem.indexPathBeforeUpdate.item == NSNotFound) {
                    [reloadedSections addIndex:updateItem.indexPathBeforeUpdate.section];
                } else {
                    [reloadedIndexPaths addObject:updateItem.indexPathBeforeUpdate];
                }
                break;
            case UICollectionUpdateActionMove:
                if (updateItem.indexPathBeforeUpdate.item == NSNotFound) {
                    movedSections[@(updateItem.indexPathBeforeUpdate.section)] = @(updateItem.indexPathAfterUpdate.section);
                } else {
                    [movedIndexPaths addObject:updateItem];
                }
                break;
            default:
                break;
        }
    }];
    
    auto insertedLayoutAttributes = [NSMutableArray<UICollectionViewLayoutAttributes *> new];
    
    
    [self deleteIndexPaths:deletedIndexPaths];
    [deletedIndexPaths release];
    
    [self deleteSections:deletedSections];
    [deletedSections release];
    
    [self insertIndexPaths:insertedIndexPaths insertedLayoutAttributes:insertedLayoutAttributes];
    [insertedIndexPaths release];
    
    [self insertSections:insertedSections insertedLayoutAttributes:insertedLayoutAttributes];
    [insertedSections release];
    
    [self moveSections:movedSections];
    [movedSections release];
    
    [self moveIndexPaths:movedIndexPaths insertedLayoutAttributes:insertedLayoutAttributes];
    [movedIndexPaths release];
    [insertedLayoutAttributes release];
    
    [self reloadSections:reloadedSections];
    [reloadedSections release];
    
    [self reloadIndexPaths:reloadedIndexPaths];
    [reloadedIndexPaths release];
    
    //
    
    [_cachedAllAttributes enumerateObjectsUsingBlock:^(NSMutableArray<UICollectionViewLayoutAttributes *> * _Nonnull obj_1, NSUInteger idx_1, BOOL * _Nonnull stop) {
        [obj_1 enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj_2, NSUInteger idx_2, BOOL * _Nonnull stop) {
            obj_2.indexPath = [NSIndexPath indexPathForItem:idx_2 inSection:idx_1];
        }];
    }];
    
    //
    
    [self updateGeometry];
    
    //
    
    NSLog(@"%@", self.allCachedAllAttributes);
    
    [super prepareForCollectionViewUpdates:updateItems];
}

- (void)deleteSections:(NSMutableIndexSet *)deletedSections __attribute__((objc_direct)) {
    [_cachedAllAttributes removeObjectsAtIndexes:deletedSections];
}

- (void)deleteIndexPaths:(NSMutableArray<NSIndexPath *> *)deletedIndexPaths __attribute__((objc_direct)) {
    [deletedIndexPaths sortUsingComparator:^NSComparisonResult(NSIndexPath  * _Nonnull obj1, NSIndexPath * _Nonnull obj2) {
        return [obj2 compare:obj1]; // reversed
    }];
    
    [deletedIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [_cachedAllAttributes[obj.section] removeObjectAtIndex:obj.item];
    }];
}

- (void)insertSections:(NSMutableIndexSet *)insertedSections insertedLayoutAttributes:(NSMutableArray<UICollectionViewLayoutAttributes *> *)insertedLayoutAttributes __attribute__((objc_direct)) {
    [insertedSections enumerateIndexesUsingBlock:^(NSUInteger section, BOOL * _Nonnull stop) {
        NSUInteger numberOfItems = [self.collectionView numberOfItemsInSection:section];
        auto layoutAttributesForSection = [[NSMutableArray<UICollectionViewLayoutAttributes *> alloc] initWithCapacity:numberOfItems];
        
        std::vector<NSInteger> itemIndexes(numberOfItems);
        std::iota(itemIndexes.begin(), itemIndexes.end(), 0);
        
        std::for_each(itemIndexes.cbegin(),
                      itemIndexes.cend(),
                      [layoutAttributesForSection, insertedLayoutAttributes, section](NSInteger item) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
            
            UICollectionViewLayoutAttributes *layoutAttributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
            layoutAttributes.frame = CGRectMake(0.f, 0.f, 0.f, kListCollectionViewLayoutEstimantedHeight);
            
            [insertedLayoutAttributes addObject:layoutAttributes];
            [layoutAttributesForSection addObject:layoutAttributes];
        });
        
        [_cachedAllAttributes insertObject:layoutAttributesForSection atIndex:section];
        [layoutAttributesForSection release];
    }];
}

- (void)insertIndexPaths:(NSMutableArray<NSIndexPath *> *)insertedIndexPaths insertedLayoutAttributes:(NSMutableArray<UICollectionViewLayoutAttributes *> *)insertedLayoutAttributes __attribute__((objc_direct)) {
    [insertedIndexPaths sortUsingComparator:^NSComparisonResult(NSIndexPath * _Nonnull obj1, NSIndexPath * _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    [insertedIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        UICollectionViewLayoutAttributes *layoutAttributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:obj];
        layoutAttributes.frame = CGRectMake(0.f,
                                            0.f,
                                            0.f,
                                            kListCollectionViewLayoutEstimantedHeight);
        [insertedLayoutAttributes addObject:layoutAttributes];
        
        [_cachedAllAttributes[obj.section] insertObject:layoutAttributes atIndex:obj.item];
    }];
}

- (void)moveSections:(NSMutableDictionary<NSNumber *, NSNumber *> *)movedSections __attribute__((objc_direct)) {
    // key: after index, value: cahced attributes for section
    auto removedCachedAttibutesForMove = [NSMutableDictionary<NSNumber *, NSMutableArray<UICollectionViewLayoutAttributes *> *> new];
    auto movedSections_before = [NSMutableIndexSet new];
    [movedSections.allKeys enumerateObjectsUsingBlock:^(NSNumber * _Nonnull before, NSUInteger idx, BOOL * _Nonnull stop) {
        NSNumber *after = movedSections[before];
        removedCachedAttibutesForMove[after] = _cachedAllAttributes[before.integerValue];
        [movedSections_before addIndex:before.integerValue];
    }];
    
    [_cachedAllAttributes removeObjectsAtIndexes:movedSections_before];
    [movedSections_before release];
    
    auto sorted_removedCachedAttibutesForMoveKeys = [removedCachedAttibutesForMove.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSNumber * _Nonnull obj1, NSNumber * _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    [sorted_removedCachedAttibutesForMoveKeys enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [_cachedAllAttributes insertObject:removedCachedAttibutesForMove[obj] atIndex:obj.integerValue];
    }];
    [removedCachedAttibutesForMove release];
}

- (void)moveIndexPaths:(NSMutableArray<UICollectionViewUpdateItem *> *)movedIndexPaths insertedLayoutAttributes:(NSMutableArray<UICollectionViewLayoutAttributes *> *)insertedLayoutAttributes __attribute__((objc_direct)) {
    auto removedAttributesForMove = [NSMutableDictionary<NSIndexPath *, UICollectionViewLayoutAttributes *> new];
    
    [movedIndexPaths enumerateObjectsUsingBlock:^(UICollectionViewUpdateItem * _Nonnull obj_1, NSUInteger idx_1, BOOL * _Nonnull stop_1) {
        [_cachedAllAttributes enumerateObjectsUsingBlock:^(NSMutableArray<UICollectionViewLayoutAttributes *> * _Nonnull obj_2, NSUInteger idx_2, BOOL * _Nonnull stop_2) {
            [obj_2 enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj_3, NSUInteger idx_3, BOOL * _Nonnull stop_3) {
                if (![insertedLayoutAttributes containsObject:obj_3] && [obj_3.indexPath isEqual:obj_1.indexPathBeforeUpdate]) {
                    removedAttributesForMove[obj_1.indexPathAfterUpdate] = obj_3;
                    [obj_2 removeObjectAtIndex:idx_3];
                    *stop_2 = YES;
                    *stop_3 = YES;
                }
            }];
        }];
    }];
    
    auto removedAttributesForMove_sortedKeys = [removedAttributesForMove.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath * _Nonnull obj1, NSIndexPath * _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    
    [removedAttributesForMove_sortedKeys enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [_cachedAllAttributes[obj.section] insertObject:removedAttributesForMove[obj] atIndex:obj.item];
    }];
    
    [removedAttributesForMove release];
}

- (void)reloadSections:(NSMutableIndexSet *)reloadedSections __attribute__((objc_direct)) {
    [reloadedSections enumerateIndexesUsingBlock:^(NSUInteger section, BOOL * _Nonnull stop) {
        auto cachedAttributesForSection = [NSMutableArray<UICollectionViewLayoutAttributes *> new];
        _cachedAllAttributes[section] = cachedAttributesForSection;
        
        NSUInteger numberOfItems = [self.collectionView numberOfItemsInSection:section];
        
        std::vector<NSInteger> itemIndexes(numberOfItems);
        std::iota(itemIndexes.begin(), itemIndexes.end(), 0);
        
        std::for_each(itemIndexes.cbegin(),
                      itemIndexes.cend(),
                      [cachedAttributesForSection, section](NSInteger item) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
            
            UICollectionViewLayoutAttributes *layoutAttributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
            layoutAttributes.frame = CGRectMake(0.f, 0.f, 0.f, kListCollectionViewLayoutEstimantedHeight);
            [cachedAttributesForSection addObject:layoutAttributes];
        });
        
        [cachedAttributesForSection release];
    }];
}

- (void)reloadIndexPaths:(NSMutableArray<NSIndexPath *> *)reloadedIndexPaths __attribute__((objc_direct)) {
    [reloadedIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        UICollectionViewLayoutAttributes *layoutAttributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:obj];
        layoutAttributes.frame = CGRectMake(0.f, 0.f, 0.f, kListCollectionViewLayoutEstimantedHeight);
        
        _cachedAllAttributes[obj.section][obj.item] = layoutAttributes;
    }];
}

- (void)updateGeometry __attribute__((objc_direct)) {
    CGFloat width = self.collectionView.bounds.size.width;
    __block CGFloat totalHeight = 0.f;
    
    [_cachedAllAttributes enumerateObjectsUsingBlock:^(NSMutableArray<UICollectionViewLayoutAttributes *> * _Nonnull obj_1, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj_1 enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj_2, NSUInteger idx, BOOL * _Nonnull stop) {
            obj_2.frame = CGRectMake(0.f,
                                     totalHeight,
                                     width,
                                     obj_2.frame.size.height);
            
            obj_2.alpha = 1.f;
            
            totalHeight += obj_2.frame.size.height;
        }];
    }];
    
    _collectionViewContentSize = CGSizeMake(width, totalHeight);
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (_cachedAllAttributes.count <= indexPath.section) {
        return nil;
    }
    
    auto cachedAttributesForSection = _cachedAllAttributes[indexPath.section];
    
    if (cachedAttributesForSection.count <= indexPath.item) {
        return nil;
        
    }
    return cachedAttributesForSection[indexPath.item];
}

- (NSArray<__kindof UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSUInteger count = self.allCachedAllAttributes.count;
    
    if (count == 0) {
        return nil;
    }
    
    NSInteger firstMatchIndex = [self binSearchWithRect:rect startIndex:0 endIndex:count - 1];
    if (firstMatchIndex == NSNotFound) {
        return nil;
    }
    
    //
    
    auto results = [NSMutableArray<UICollectionViewLayoutAttributes *> new];
    
    [[self.allCachedAllAttributes objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, firstMatchIndex)]] enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger , BOOL * _Nonnull stop) {
        if (CGRectGetMaxY(obj.frame) < CGRectGetMinY(rect)) {
            *stop = YES;
            return;
        }
        
        [results addObject:obj];
    }];
    
    [[self.allCachedAllAttributes objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstMatchIndex, count - firstMatchIndex)]] enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (CGRectGetMinY(obj.frame) > CGRectGetMaxY(rect)) {
            *stop = YES;
            return;
        }
        
        [results addObject:obj];
    }];
    
    //
    
    return [results autorelease];
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return !CGSizeEqualToSize(self.collectionView.bounds.size, newBounds.size);
}

- (BOOL)shouldInvalidateLayoutForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes {
    BOOL result = preferredAttributes.frame.size.height != originalAttributes.frame.size.height;
    return result;
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes {
    UICollectionViewLayoutInvalidationContext *context = [UICollectionViewLayoutInvalidationContext new];
    
    [context invalidateItemsAtIndexPaths:@[preferredAttributes.indexPath]];
    
    objc_setAssociatedObject(context, preferredAttributesArrayKey, @[preferredAttributes], OBJC_ASSOCIATION_COPY_NONATOMIC);
    
    context.contentSizeAdjustment = CGSizeMake(0.f,
                                               preferredAttributes.frame.size.height - originalAttributes.frame.size.height);
    
    return [context autorelease];
}

- (void)invalidateLayoutWithContext:(UICollectionViewLayoutInvalidationContext *)context {
    auto allPreferredAttributes = static_cast<NSArray<UICollectionViewLayoutAttributes *> *>(objc_getAssociatedObject(context, preferredAttributesArrayKey));
    
    [allPreferredAttributes enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSIndexPath *indexPath = obj.indexPath;
        _cachedAllAttributes[indexPath.section][indexPath.item].frame = CGRectMake(0.f,
                                                                                   0.f,
                                                                                   0.f,
                                                                                   obj.frame.size.height);
    }];
    
    [self updateGeometry];
    
    [super invalidateLayoutWithContext:context];
}

- (NSInteger)binSearchWithRect:(CGRect)rect startIndex:(NSInteger)startIndex endIndex:(NSInteger)endIndex __attribute__((objc_direct)) {
    if (endIndex < startIndex) return NSNotFound;
    
    NSInteger midIndex = (startIndex + endIndex) / 2;
    UICollectionViewLayoutAttributes *attributes = self.allCachedAllAttributes[midIndex];
    
    if (CGRectIntersectsRect(attributes.frame, rect)) {
        return midIndex;
    } else {
        if (CGRectGetMaxY(attributes.frame) < CGRectGetMinY(rect)) {
            return [self binSearchWithRect:rect startIndex:midIndex + 1 endIndex:endIndex];
        } else {
            return [self binSearchWithRect:rect startIndex:startIndex endIndex:midIndex - 1];
        }
    }
}

@end
