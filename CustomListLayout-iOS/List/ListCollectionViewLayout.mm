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
    
    [[_cachedAllAttributes objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(lastIndex, _cachedAllAttributes.count - lastIndex)]] enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSIndexPath *objIndexPath = obj.indexPath;
        NSInteger objSection = objIndexPath.section;
        NSInteger objItem = objIndexPath.item;
        
        if (objSection == section) {
            obj.indexPath = [NSIndexPath indexPathForItem:objItem - 1 inSection:objSection];
        }
        
        CGRect frame = obj.frame;
        obj.frame = CGRectMake(frame.origin.x,
                               frame.origin.y - totalDeletedHeight,
                               frame.size.width,
                               frame.size.height);
    }];
    
    _collectionViewContentSize.height -= totalDeletedHeight;
}

- (void)reloadCachedAttributesForIndexPath:(NSIndexPath *)indexPath __attribute__((objc_direct)) {
    
}

- (void)moveCachedAttributesFromIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath __attribute__((objc_direct)) {
    if (fromIndexPath.item == NSNotFound && toIndexPath.item == NSNotFound) {
        
        return;
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

@end
