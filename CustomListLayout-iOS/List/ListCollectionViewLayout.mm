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

+ (Class)layoutAttributesClass {
    return UICollectionViewLayoutAttributes.class;
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
    
    [super prepareLayout];
}

- (void)prepareForCollectionViewUpdates:(NSArray<UICollectionViewUpdateItem *> *)updateItems {
    NSLog(@"%@", updateItems);
    
    NSUInteger count = updateItems.count;
    auto movedSectionItems = [NSMutableArray<UICollectionViewUpdateItem *> new];
    
    [updateItems enumerateObjectsUsingBlock:^(UICollectionViewUpdateItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        NSLog(@"%@", item);
        
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
        
        NSLog(@"%@", _cachedAllAttributes);
    }];
    
    [movedSectionItems enumerateObjectsUsingBlock:^(UICollectionViewUpdateItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self moveCachedAttributesFromIndexPath:obj.indexPathBeforeUpdate toIndexPath:obj.indexPathAfterUpdate];
    }];
    
    [movedSectionItems release];
    
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
    NSUInteger count = _cachedAllAttributes.count;
    
    if (count == 0) {
        return nil;
    }
    
    NSInteger firstMatchIndex = [self binSearchWithRect:rect startIndex:0 endIndex:count - 1];
    if (firstMatchIndex == NSNotFound) {
        return nil;
    }
    
    //
    
    auto results = [NSMutableArray<UICollectionViewLayoutAttributes *> new];
    
    [[_cachedAllAttributes objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, firstMatchIndex)]] enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (CGRectGetMaxY(obj.frame) < CGRectGetMinY(rect)) {
            *stop = YES;
            return;
        }
        
        [results addObject:obj];
    }];
    
    [[_cachedAllAttributes objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstMatchIndex, count - firstMatchIndex)]] enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (CGRectGetMinY(obj.frame) > CGRectGetMaxY(rect)) {
            *stop = YES;
            return;
        }
        
        [results addObject:obj];
    }];
    
    //
    
    auto copy = static_cast<NSArray<UICollectionViewLayoutAttributes *> *>([results copy]);
    [results release];
    return [copy autorelease];
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

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return !CGRectEqualToRect(self.collectionView.bounds, newBounds);
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
        
        for (UICollectionViewLayoutAttributes *attributes in _cachedAllAttributes) {
            if (attributes.indexPath.section == section) {
                return;
            }
        }
        
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
        [_cachedAllAttributes enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSIndexPath *objIndexPath = obj.indexPath;
            
            if (item == 0) {
                if (objIndexPath.section == section - 1) {
                    targetIndex = idx + 1;
                    *stop = YES;
                }
            } else {
                if (objIndexPath.section == section) {
                    if (objIndexPath.item < item) {
                        if (targetIndex == NSNotFound) {
                            targetIndex = idx + 1;
                        } else {
                            targetIndex = MAX(targetIndex, idx + 1);
                        }
                    } else if (targetIndex != NSNotFound) {
                        *stop = YES;
                    }
                } else if (targetIndex != NSNotFound) {
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
    
    _collectionViewContentSize = CGSizeMake(self.collectionView.bounds.size.width,
                                            _collectionViewContentSize.height + kListCollectionViewLayoutEstimantedHeight);
    
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
    }];
}

- (void)deleteCachedAttributesForIndexPath:(NSIndexPath *)indexPath __attribute__((objc_direct)) {
    NSInteger section = indexPath.section;
    NSInteger item = indexPath.item;
    
    __block NSInteger lastIndex = NSNotFound;
    __block CGFloat totalDeletedHeight = 0.f;
    
    [_cachedAllAttributes enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.indexPath.section == section && (item == NSNotFound || obj.indexPath.item == item)) {
            lastIndex = MIN(lastIndex, idx);
            
            totalDeletedHeight += obj.frame.size.height;
            [_cachedAllAttributes removeObjectAtIndex:idx];
            
            if (item == idx) {
                *stop = YES;
            }
        }
    }];
    
    assert(lastIndex != NSNotFound);
    
    [[_cachedAllAttributes objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(lastIndex, _cachedAllAttributes.count - lastIndex)]] enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSIndexPath *objIndexPath = obj.indexPath;
        NSInteger objSection = objIndexPath.section;
        NSInteger objItem = objIndexPath.item;
        
//        if (objSection == section) {
//            obj.indexPath = [NSIndexPath indexPathForItem:objItem - 1 inSection:objSection];
//        }
        
        CGRect frame = obj.frame;
        obj.frame = CGRectMake(frame.origin.x,
                               frame.origin.y - totalDeletedHeight,
                               frame.size.width,
                               frame.size.height);
    }];
    
    _collectionViewContentSize.height -= totalDeletedHeight;
}

- (void)finalizeDeletingCachedAttributes __attribute__((objc_direct)) {
    __block NSIndexPath *lastIndexPath = nil;
    
    [_cachedAllAttributes enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (lastIndexPath) {
            if (lastIndexPath.section == obj.indexPath.section && lastIndexPath.item + 1 < obj.indexPath.item) {
                obj.indexPath = [NSIndexPath indexPathForItem:lastIndexPath.item + 1 inSection:lastIndexPath.section];
            }
        }
        
        lastIndexPath = obj.indexPath;
    }];
}

- (void)reloadCachedAttributesForIndexPath:(NSIndexPath *)indexPath __attribute__((objc_direct)) {
    // slow
//    [self deleteCachedAttributesForIndexPath:indexPath];
//    [self insertCachedAttributesForIndexPath:indexPath];
    
    if (indexPath.item == NSNotFound) {
        NSInteger section = indexPath.section;
        NSInteger numberOfItems = [self.collectionView numberOfItemsInSection:section];
        
        std::vector<NSInteger> itemIndexes(numberOfItems);
        std::iota(itemIndexes.begin(), itemIndexes.end(), 0);
        
        std::for_each(itemIndexes.cbegin(),
                      itemIndexes.cend(),
                      [self, section](NSInteger item) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
            [self _reloadCachedAttributesForIndexPath:indexPath];
        });
    } else {
        [self _reloadCachedAttributesForIndexPath:indexPath];
    }
}

- (void)_reloadCachedAttributesForIndexPath:(NSIndexPath *)indexPath __attribute__((objc_direct)) {
    __block NSInteger index = NSNotFound;
    __block UICollectionViewLayoutAttributes *attributes = nil;
    
    [_cachedAllAttributes enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.indexPath isEqual:indexPath]) {
            attributes = obj;
            index = idx;
            *stop = YES;
        }
    }];
    
    assert(index != NSNotFound);
    
    CGFloat heightDiff = kListCollectionViewLayoutEstimantedHeight - attributes.frame.size.height;
    attributes.frame = CGRectMake(attributes.frame.origin.x,
                                  attributes.frame.origin.y,
                                  attributes.frame.size.width,
                                  kListCollectionViewLayoutEstimantedHeight);
    
    _collectionViewContentSize = CGSizeMake(_collectionViewContentSize.width,
                                            _collectionViewContentSize.height + heightDiff);
    
    if (index < _cachedAllAttributes.count - 1) {
        NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index + 1, _cachedAllAttributes.count - index - 1)];
        [[_cachedAllAttributes objectsAtIndexes:indexes] enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj.frame = CGRectMake(obj.frame.origin.x,
                                   obj.frame.origin.y + heightDiff,
                                   obj.frame.size.width,
                                   obj.frame.size.height);
        }];
    }
}


- (void)moveCachedAttributesFromIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath __attribute__((objc_direct)) {
//    if (fromIndexPath.section != toIndexPath.section) {
//        static_cast<UICollectionViewLayoutAttributes *>([self layoutAttributesForItemAtIndexPath:fromIndexPath]).pendingIndexPath = toIndexPath;
//        return;
//    }
//    
//    if ([self layoutAttributesForItemAtIndexPath:toIndexPath] == nil) {
//        static_cast<UICollectionViewLayoutAttributes *>([self layoutAttributesForItemAtIndexPath:fromIndexPath]).pendingIndexPath = toIndexPath;
//        return;
//    }
    
    if (fromIndexPath.item == NSNotFound && toIndexPath.item == NSNotFound) {
        __block NSInteger firstFromSectionIndex = NSNotFound;
        __block CGFloat fromTotalHeight = 0.f;
        __block CGFloat didFinishGettingFromTotalHeight = YES;
        __block NSInteger firstToSectionIndex = NSNotFound;
        
        [_cachedAllAttributes enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSIndexPath *indexPath = obj.indexPath;
            
            if (indexPath.section == fromIndexPath.section) {
                if (indexPath.item == 0) {
                    firstFromSectionIndex = idx;
                } 
                
                fromTotalHeight += obj.frame.size.height;
                didFinishGettingFromTotalHeight = NO;
            } else {
                didFinishGettingFromTotalHeight = YES;
            }
            
            if (indexPath.section == toIndexPath.section && indexPath.item == 0) {
                firstToSectionIndex = idx;
            }
            
            if (firstFromSectionIndex != NSNotFound && firstToSectionIndex != NSNotFound && didFinishGettingFromTotalHeight) {
                *stop = YES;
            }
        }];
        
        assert(firstFromSectionIndex != NSNotFound);
        assert(firstToSectionIndex != NSNotFound);
        
        //
        
        if (firstFromSectionIndex < firstToSectionIndex) {
            // Data Source에는 이미 Move가 반영되었기 때문에 To에서 가져온다.
            NSUInteger numberIfItemsInFromSection = [self.collectionView numberOfItemsInSection:toIndexPath.section];
            NSUInteger numberIfItemsInToSection = [self.collectionView numberOfItemsInSection:toIndexPath.section - 1];
            
            NSIndexSet *indexes_1 = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstFromSectionIndex + numberIfItemsInFromSection,
                                                                                       (firstToSectionIndex + numberIfItemsInToSection) - (firstFromSectionIndex + numberIfItemsInFromSection))];
            
            [[_cachedAllAttributes objectsAtIndexes:indexes_1] enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                obj.frame = CGRectMake(obj.frame.origin.x,
                                       obj.frame.origin.y - fromTotalHeight,
                                       obj.frame.size.width,
                                       obj.frame.size.height);
                
                obj.indexPath = [NSIndexPath indexPathForItem:obj.indexPath.item inSection:obj.indexPath.section - 1];
            }];
            
            CGRect toLastFrame = _cachedAllAttributes[firstToSectionIndex + numberIfItemsInToSection - 1].frame;
            __block CGFloat offsetY = CGRectGetMaxY(toLastFrame); 
            
            NSIndexSet *indexes_2 = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstFromSectionIndex, numberIfItemsInFromSection)];
            NSArray<UICollectionViewLayoutAttributes *> *fromAttributes = [_cachedAllAttributes objectsAtIndexes:indexes_2];
            [fromAttributes enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                obj.frame = CGRectMake(obj.frame.origin.x,
                                       offsetY,
                                       obj.frame.size.width,
                                       obj.frame.size.height);
                
                offsetY += obj.frame.size.height;
                obj.indexPath = [NSIndexPath indexPathForItem:obj.indexPath.item inSection:toIndexPath.section];
            }];
            
            [_cachedAllAttributes removeObjectsAtIndexes:indexes_2];
            [_cachedAllAttributes insertObjects:fromAttributes atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstToSectionIndex + numberIfItemsInToSection - numberIfItemsInFromSection, numberIfItemsInFromSection)]];
        } else {
            // Data Source에는 이미 Move가 반영되었기 때문에 To에서 가져온다.
            NSUInteger numberIfItemsInFromSection = [self.collectionView numberOfItemsInSection:toIndexPath.section];
            NSUInteger numberIfItemsInToSection = [self.collectionView numberOfItemsInSection:toIndexPath.section + 1];
            
            NSIndexSet *indexes_1 = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstToSectionIndex,
                                                                                       firstFromSectionIndex - firstToSectionIndex)];
            
            CGRect toFirstFrame = _cachedAllAttributes[firstToSectionIndex].frame;
            
            [[_cachedAllAttributes objectsAtIndexes:indexes_1] enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                obj.frame = CGRectMake(obj.frame.origin.x,
                                       obj.frame.origin.y + fromTotalHeight,
                                       obj.frame.size.width,
                                       obj.frame.size.height);
                
                obj.indexPath = [NSIndexPath indexPathForItem:obj.indexPath.item inSection:obj.indexPath.section + 1];
            }];
            
            __block CGFloat offsetY = CGRectGetMinY(toFirstFrame);
            
            NSIndexSet *indexes_2 = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstFromSectionIndex, numberIfItemsInFromSection)];
            NSArray<UICollectionViewLayoutAttributes *> *fromAttributes = [_cachedAllAttributes objectsAtIndexes:indexes_2];
            [fromAttributes enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                obj.frame = CGRectMake(obj.frame.origin.x,
                                       offsetY,
                                       obj.frame.size.width,
                                       obj.frame.size.height);
                
                offsetY += obj.frame.size.height;
                obj.indexPath = [NSIndexPath indexPathForItem:obj.indexPath.item inSection:toIndexPath.section];
            }];
            
            [_cachedAllAttributes removeObjectsAtIndexes:indexes_2];
            [_cachedAllAttributes insertObjects:fromAttributes atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstToSectionIndex, numberIfItemsInFromSection)]];
        }
        
        
    } else {
        [self _moveCachedAttributesFromIndexPath:fromIndexPath toIndexPath:toIndexPath];
    }
}

- (void)_moveCachedAttributesFromIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath __attribute__((objc_direct)) {
    assert(fromIndexPath.item != NSNotFound);
    assert(toIndexPath.item != NSNotFound);
    
    __block UICollectionViewLayoutAttributes *fromAttributes = nil;
    __block UICollectionViewLayoutAttributes *toAttributes = nil;
    __block NSInteger fromIndex = NSNotFound;
    __block NSInteger toIndex = NSNotFound;
    
    [_cachedAllAttributes enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.indexPath isEqual:fromIndexPath]) {
            fromAttributes = obj;
            fromIndex = idx;
        } else if ([obj.indexPath isEqual:toIndexPath]) {
            toAttributes = obj;
            toIndex = idx;
        }
        
        if (fromIndex != NSNotFound && toIndex != NSNotFound) {
            *stop = YES;
        }
    }];
    
    assert(fromIndex != NSNotFound);
    assert(toIndex != NSNotFound);
    
    [[fromAttributes retain] autorelease];
    [[toAttributes retain] autorelease];
    
    CGFloat toY = toAttributes.frame.origin.y;
    
    [_cachedAllAttributes removeObjectAtIndex:fromIndex];
    [_cachedAllAttributes insertObject:fromAttributes atIndex:toIndex];
    
    if (fromIndex < toIndex) {
        NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(fromIndex + 1, toIndex - fromIndex - 1)];
        [[_cachedAllAttributes objectsAtIndexes:indexes] enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj.indexPath = _cachedAllAttributes[fromIndex + 1 + idx - 1].indexPath;
            
            obj.frame = CGRectMake(obj.frame.origin.x,
                                   obj.frame.origin.y - fromAttributes.frame.size.height,
                                   obj.frame.size.width,
                                   obj.frame.size.height);
        }];
        
        _cachedAllAttributes[fromIndex].frame = CGRectMake(_cachedAllAttributes[fromIndex].frame.origin.x,
                                                           _cachedAllAttributes[fromIndex].frame.origin.y - fromAttributes.frame.size.height,
                                                           _cachedAllAttributes[fromIndex].frame.size.width,
                                                           _cachedAllAttributes[fromIndex].frame.size.height);
    } else {
        NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(toIndex + 1, fromIndex - toIndex - 1)];
        [[_cachedAllAttributes objectsAtIndexes:indexes] enumerateObjectsWithOptions:0 usingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj.indexPath = _cachedAllAttributes[toIndex + 1 + idx + 1].indexPath;
            
            obj.frame = CGRectMake(obj.frame.origin.x,
                                   obj.frame.origin.y + fromAttributes.frame.size.height,
                                   obj.frame.size.width,
                                   obj.frame.size.height);
        }];
        
        _cachedAllAttributes[fromIndex].frame = CGRectMake(_cachedAllAttributes[fromIndex].frame.origin.x,
                                                           _cachedAllAttributes[fromIndex].frame.origin.y + fromAttributes.frame.size.height,
                                                           _cachedAllAttributes[fromIndex].frame.size.width,
                                                           _cachedAllAttributes[fromIndex].frame.size.height);
    }
    
    _cachedAllAttributes[fromIndex].indexPath = fromAttributes.indexPath;
    fromAttributes.indexPath = toIndexPath;
    
    if (toIndex == 0) {
        fromAttributes.frame = CGRectMake(fromAttributes.frame.origin.x,
                                          toY,
                                          fromAttributes.frame.size.width,
                                          fromAttributes.frame.size.height);
    } else {
        fromAttributes.frame = CGRectMake(fromAttributes.frame.origin.x,
                                          CGRectGetMaxY(_cachedAllAttributes[toIndex - 1].frame),
                                          fromAttributes.frame.size.width,
                                          fromAttributes.frame.size.height);
    }
}

- (NSInteger)binSearchWithRect:(CGRect)rect startIndex:(NSInteger)startIndex endIndex:(NSInteger)endIndex __attribute__((objc_direct)) {
    if (endIndex < startIndex) return NSNotFound;
    
    NSInteger midIndex = (startIndex + endIndex) / 2;
    UICollectionViewLayoutAttributes *attributes = _cachedAllAttributes[midIndex];
    
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
