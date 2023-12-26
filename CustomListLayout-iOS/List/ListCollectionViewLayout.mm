//
//  ListCollectionViewLayout.mm
//  CustomListLayout-iOS
//
//  Created by Jinwoo Kim on 12/23/23.
//

#import "ListCollectionViewLayout.hpp"
#import <numeric>
#import <algorithm>

/*
 diff는 중간 반영된 값이 아님
 따라서 cachedAllAttributes를 Section: Array 기반으로 바꿔줘야 해결됨
 (
     "MOV(1-0)->(4-0)",
     "MOV(1-1)->(4-1)",
     "MOV(1-2)->(4-2)",
     "MOV(1-3)->(4-3)",
     "MOV(1-4)->(4-4)",
     "MOV(1-5)->(4-5)",
     "SEC:MOV(1)->(4)",
     "MOV(4-0)->(0-0)",
     "MOV(4-1)->(0-1)",
     "MOV(4-2)->(0-2)",
     "SEC:MOV(4)->(0)",
     "MOV(5-0)->(2-0)",
     "MOV(5-1)->(2-1)",
     "MOV(5-2)->(2-2)",
     "SEC:MOV(5)->(2)"
 )
 */
#define kListCollectionViewLayoutEstimantedHeight 44.f

@interface _ListCollectionViewLayoutAttributes : UICollectionViewLayoutAttributes
@property (copy, nonatomic, direct) NSIndexPath * _Nullable beforeIndexPath;
@end
@implementation _ListCollectionViewLayoutAttributes
- (void)dealloc {
    [_beforeIndexPath release];
    [super dealloc];
}
- (id)copyWithZone:(struct _NSZone *)zone {
    auto copy = static_cast<decltype(self)>([super copyWithZone:zone]);
    copy.beforeIndexPath = _beforeIndexPath;
    return copy;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"%@ %@", [super description], _beforeIndexPath];
}
- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    } else if (![super isEqual:other]) {
        return NO;
    } else {
        return [_beforeIndexPath isEqual:static_cast<decltype(self)>(other).beforeIndexPath];
    }
}

- (NSUInteger)hash {
    return [super hash] ^ _beforeIndexPath.hash;
}
@end

__attribute__((objc_direct_members))
@interface ListCollectionViewLayout () {
    CGSize _collectionViewContentSize;
}
@property (retain, nonatomic) NSMutableArray<_ListCollectionViewLayoutAttributes *> *cachedAllAttributes;
@property (assign, readonly, nonatomic) NSOrderedSet<_ListCollectionViewLayoutAttributes *> *sortedCachedAllAttributes;
@property (retain, nonatomic) NSMutableSet<_ListCollectionViewLayoutAttributes *> *invalidatedAllAttributes;
@end

@implementation ListCollectionViewLayout

+ (Class)invalidationContextClass {
    return UICollectionViewLayoutInvalidationContext.class;
}

+ (Class)layoutAttributesClass {
    return _ListCollectionViewLayoutAttributes.class;
}

- (instancetype)init {
    if (self = [super init]) {
        _cachedAllAttributes = [NSMutableArray<_ListCollectionViewLayoutAttributes *> new];
        _invalidatedAllAttributes = [NSMutableSet<_ListCollectionViewLayoutAttributes *> new];
    }
    
    return self;
}

- (void)dealloc {
    [_cachedAllAttributes release];
    [_invalidatedAllAttributes release];
    [super dealloc];
}

- (NSOrderedSet<_ListCollectionViewLayoutAttributes *> *)sortedCachedAllAttributes {
    NSArray<_ListCollectionViewLayoutAttributes *> *sortedArray = [_cachedAllAttributes sortedArrayUsingComparator:^NSComparisonResult(_ListCollectionViewLayoutAttributes * _Nonnull obj1, _ListCollectionViewLayoutAttributes * _Nonnull obj2) {
        return [obj1.indexPath compare:obj2.indexPath];
    }];
    
    return [NSOrderedSet<_ListCollectionViewLayoutAttributes *> orderedSetWithArray:sortedArray];
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
    
    // TODO: Initial Data Source
//    NSInteger numberOfSections = collectionView.numberOfSections;
//    if (numberOfSections == 0) {
//        [super prepareLayout];
//        return;
//    }
//    
//    std::vector<NSInteger> sectionIndexes(numberOfSections);
//    std::iota(sectionIndexes.begin(), sectionIndexes.end(), 0);
//    
//    std::for_each(sectionIndexes.cbegin(),
//                  sectionIndexes.cend(),
//                  [collectionView, self](NSInteger section) {
//        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:NSNotFound inSection:section];
//        [self insertCachedAttributesForIndexPath:indexPath];
//    });
    
    [super prepareLayout];
}

- (void)prepareForCollectionViewUpdates:(NSArray<UICollectionViewUpdateItem *> *)updateItems {
    [_cachedAllAttributes enumerateObjectsUsingBlock:^(_ListCollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.beforeIndexPath = obj.indexPath;
    }];
    
//    NSLog(@"%@", updateItems);
    
    NSUInteger count = updateItems.count;
    auto movedSectionItems = [NSMutableArray<UICollectionViewUpdateItem *> new];
    
    [updateItems enumerateObjectsUsingBlock:^(UICollectionViewUpdateItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
//        NSLog(@"%@", item);
        
        switch (item.updateAction) {
            case UICollectionUpdateActionInsert:
                [self insertCachedAttributesForIndexPath:item.indexPathAfterUpdate];
                break;
            case UICollectionUpdateActionDelete:
                [self deleteCachedAttributesForIndexPath:item.indexPathBeforeUpdate];
                
                if (idx + 1 < count) {
                    if (updateItems[idx +1].updateAction != UICollectionUpdateActionDelete) {
                        [self finalizeDeletingCachedAttributes];
                    }
                } else {
                    [self finalizeDeletingCachedAttributes];
                }
                break;
            case UICollectionUpdateActionReload:
                [self reloadCachedAttributesForIndexPath:item.indexPathBeforeUpdate];
                break;
            case UICollectionUpdateActionMove:
                if (item.indexPathAfterUpdate.item == NSNotFound) {
//                    [self moveCachedAttributesFromIndexPath:item.indexPathBeforeUpdate toIndexPath:item.indexPathAfterUpdate];
                    [movedSectionItems addObject:item];
                } else {
                    NSIndexPath *fromIndexPath = item.indexPathBeforeUpdate;
                    NSIndexPath *toIndexPath = [NSIndexPath indexPathForItem:item.indexPathAfterUpdate.item inSection:fromIndexPath.section];
                    
                    if ([fromIndexPath isEqual:toIndexPath]) return;
                    [self moveCachedAttributesFromIndexPath:fromIndexPath toIndexPath:toIndexPath];
                }
                break;
            default:
                break;
        }
        
//        NSLog(@"%@", _cachedAllAttributes);
    }];
    
    [movedSectionItems enumerateObjectsUsingBlock:^(UICollectionViewUpdateItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self moveCachedAttributesFromIndexPath:obj.indexPathBeforeUpdate toIndexPath:obj.indexPathAfterUpdate];
    }];
    
    [movedSectionItems release];
    
    NSLog(@"%@", self.sortedCachedAllAttributes);
    
    [super prepareForCollectionViewUpdates:updateItems];
}

- (_ListCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    for (_ListCollectionViewLayoutAttributes *layoutAttributes in _cachedAllAttributes) {
        if ([layoutAttributes.indexPath isEqual:indexPath]) {
            return layoutAttributes;
        }
    }
    
    return nil;
}

- (NSArray<__kindof _ListCollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSUInteger count = self.sortedCachedAllAttributes.count;
    
    if (count == 0) {
        return nil;
    }
    
    NSInteger firstMatchIndex = [self binSearchWithRect:rect startIndex:0 endIndex:count - 1];
    if (firstMatchIndex == NSNotFound) {
        return nil;
    }
    
    //
    
    auto results = [NSMutableArray<_ListCollectionViewLayoutAttributes *> new];
    
    [[self.sortedCachedAllAttributes objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, firstMatchIndex)]] enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(_ListCollectionViewLayoutAttributes * _Nonnull obj, NSUInteger , BOOL * _Nonnull stop) {
        if (CGRectGetMaxY(obj.frame) < CGRectGetMinY(rect)) {
            *stop = YES;
            return;
        }
        
        [results addObject:obj];
    }];
    
    [[self.sortedCachedAllAttributes objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstMatchIndex, count - firstMatchIndex)]] enumerateObjectsUsingBlock:^(_ListCollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (CGRectGetMinY(obj.frame) > CGRectGetMaxY(rect)) {
            *stop = YES;
            return;
        }
        
        [results addObject:obj];
    }];
    
    //
    
    auto copy = static_cast<NSArray<_ListCollectionViewLayoutAttributes *> *>([results copy]);
    [results release];
    return [copy autorelease];
}

- (_ListCollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)itemIndexPath {
    return [self layoutAttributesForItemAtIndexPath:itemIndexPath];
}

- (BOOL)shouldInvalidateLayoutForPreferredLayoutAttributes:(_ListCollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(_ListCollectionViewLayoutAttributes *)originalAttributes {
    BOOL result = preferredAttributes.frame.size.height != originalAttributes.frame.size.height;
    
    if (result) {
        [_invalidatedAllAttributes addObject:preferredAttributes];
    }
    
    return result;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return !CGRectEqualToRect(self.collectionView.bounds, newBounds);
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForPreferredLayoutAttributes:(_ListCollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(_ListCollectionViewLayoutAttributes *)originalAttributes {
    NSUInteger invalidatedCount = _invalidatedAllAttributes.count;
    
    if (invalidatedCount == 0) return nil;
    
    UICollectionViewLayoutInvalidationContext *context = [UICollectionViewLayoutInvalidationContext new];
    
    auto indexPaths = [[NSMutableArray<NSIndexPath *> alloc] initWithCapacity:invalidatedCount];
    
    for (_ListCollectionViewLayoutAttributes *attributes in _invalidatedAllAttributes) {
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
        
        for (_ListCollectionViewLayoutAttributes *attributes in _invalidatedAllAttributes) {
            NSIndexPath *indexPath = attributes.indexPath;
            
            //
            
            _ListCollectionViewLayoutAttributes *oldAttributes = [self layoutAttributesForItemAtIndexPath:indexPath];
            CGRect oldFrame = oldAttributes.frame;
            CGRect newFrame = attributes.frame;
            oldAttributes.frame = CGRectMake(oldFrame.origin.x,
                                             oldFrame.origin.y,
                                             oldFrame.size.width,
                                             newFrame.size.height);
            
            CGFloat diff = newFrame.size.height - oldFrame.size.height;
            
            NSUInteger index_cachedAllAttributes = [self.sortedCachedAllAttributes indexOfObject:oldAttributes];
            
            auto sub_cachedAllAttributes = [self.sortedCachedAllAttributes objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index_cachedAllAttributes + 1, count_cachedAllAttributes - index_cachedAllAttributes - 1)]];
            [sub_cachedAllAttributes enumerateObjectsUsingBlock:^(_ListCollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
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
        
        //
        
        [_cachedAllAttributes enumerateObjectsUsingBlock:^(_ListCollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.beforeIndexPath == nil) return;
            
            if (indexPath.section <= obj.beforeIndexPath.section) {
                obj.indexPath = [NSIndexPath indexPathForItem:obj.indexPath.item inSection:obj.indexPath.section + 1];
            }
        }];
        
        //
        
        NSInteger numberOfItems = [self.collectionView numberOfItemsInSection:section];
        
        std::vector<NSInteger> itemIndexes(numberOfItems);
        std::iota(itemIndexes.begin(), itemIndexes.end(), 0);
        
        std::for_each(itemIndexes.cbegin(),
                      itemIndexes.cend(),
                      [self, section](NSInteger item) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
            
            _ListCollectionViewLayoutAttributes *layoutAttributes = [_ListCollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
            [_cachedAllAttributes addObject:layoutAttributes];
        });
    } else {
        [self _insertCachedAttributesForIndexPath:indexPath];
    }
}

- (void)_insertCachedAttributesForIndexPath:(NSIndexPath *)indexPath __attribute__((objc_direct)) {
    [_cachedAllAttributes enumerateObjectsUsingBlock:^(_ListCollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.beforeIndexPath == nil) return;
        
        if (indexPath.section == obj.beforeIndexPath.section && indexPath.item <= obj.beforeIndexPath.item) {
            obj.indexPath = [NSIndexPath indexPathForItem:obj.indexPath.item + 1 inSection:indexPath.section];
        }
    }];
    
    _ListCollectionViewLayoutAttributes *layoutAttributes = [_ListCollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    [_cachedAllAttributes addObject:layoutAttributes];
}

- (void)deleteCachedAttributesForIndexPath:(NSIndexPath *)indexPath __attribute__((objc_direct)) {
    if (indexPath.item == NSNotFound) {
        auto removedIndexes = [NSMutableIndexSet new];
        
        [_cachedAllAttributes enumerateObjectsUsingBlock:^(_ListCollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.beforeIndexPath == nil) return;
            
            if (obj.beforeIndexPath.section == indexPath.section) {
                [removedIndexes addIndex:idx];
            } else if (obj.beforeIndexPath.section > indexPath.section) {
                obj.indexPath = [NSIndexPath indexPathForItem:obj.indexPath.item inSection:obj.indexPath.section - 1];
            }
        }];
        
        [_cachedAllAttributes removeObjectsAtIndexes:removedIndexes];
        [removedIndexes release];
    } else {
        __block NSInteger index = NSNotFound;
        
        [_cachedAllAttributes enumerateObjectsUsingBlock:^(_ListCollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.beforeIndexPath == nil) return;
            
            if ([obj.beforeIndexPath isEqual:indexPath]) {
                index = idx;
            } else if (obj.beforeIndexPath.section == indexPath.section && obj.beforeIndexPath.item > indexPath.item) {
                obj.indexPath = [NSIndexPath indexPathForItem:obj.indexPath.item - 1 inSection:obj.indexPath.section];
            }
        }];
        
        assert(index != NSNotFound);
        
        [_cachedAllAttributes removeObjectAtIndex:index];
    }
}

- (void)finalizeDeletingCachedAttributes __attribute__((objc_direct)) {
    __block NSIndexPath *lastIndexPath = nil;
    
    [_cachedAllAttributes enumerateObjectsUsingBlock:^(_ListCollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (lastIndexPath) {
            if (lastIndexPath.section == obj.indexPath.section && lastIndexPath.item + 1 < obj.indexPath.item) {
                obj.indexPath = [NSIndexPath indexPathForItem:lastIndexPath.item + 1 inSection:lastIndexPath.section];
            }
        }
        
        lastIndexPath = obj.indexPath;
    }];
}

- (void)reloadCachedAttributesForIndexPath:(NSIndexPath *)indexPath __attribute__((objc_direct)) {
    if (indexPath.item == NSNotFound) {
        auto removedIndexes = [NSMutableIndexSet new];
        auto insertedAttributes = [NSMutableArray<_ListCollectionViewLayoutAttributes *> new];
        
        [_cachedAllAttributes enumerateObjectsUsingBlock:^(_ListCollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.beforeIndexPath == nil) return;
            
            if (obj.beforeIndexPath.section == indexPath.section) {
                [removedIndexes addIndex:idx];
                
                _ListCollectionViewLayoutAttributes *attributes = [_ListCollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:obj.indexPath];
                attributes.beforeIndexPath = obj.beforeIndexPath;
                
                [insertedAttributes addObject:attributes];
            }
        }];
        
        [_cachedAllAttributes removeObjectsAtIndexes:removedIndexes];
        [removedIndexes release];
        [_cachedAllAttributes addObjectsFromArray:insertedAttributes];
        [insertedAttributes release];
    } else {
        [_cachedAllAttributes enumerateObjectsUsingBlock:^(_ListCollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.beforeIndexPath == nil) return;
            
            if ([obj.beforeIndexPath isEqual:indexPath]) {
                [_cachedAllAttributes removeObjectAtIndex:idx];
                
                _ListCollectionViewLayoutAttributes *attributes = [_ListCollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:obj.indexPath];
                attributes.beforeIndexPath = obj.beforeIndexPath;
                
                [_cachedAllAttributes addObject:attributes];
                
                *stop = YES;
            }
        }];
    }
}

- (void)moveCachedAttributesFromIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath __attribute__((objc_direct)) {
    if (toIndexPath.item == NSNotFound) {
        
    } else {
        [self _moveCachedAttributesFromIndexPath:fromIndexPath toIndexPath:toIndexPath];
    }
}

- (void)_moveCachedAttributesFromIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath __attribute__((objc_direct)) {
    
}

- (NSInteger)binSearchWithRect:(CGRect)rect startIndex:(NSInteger)startIndex endIndex:(NSInteger)endIndex __attribute__((objc_direct)) {
    if (endIndex < startIndex) return NSNotFound;
    
    NSInteger midIndex = (startIndex + endIndex) / 2;
    _ListCollectionViewLayoutAttributes *attributes = self.sortedCachedAllAttributes[midIndex];
    
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
