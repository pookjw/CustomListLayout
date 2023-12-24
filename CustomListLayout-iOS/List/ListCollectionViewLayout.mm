//
//  ListCollectionViewLayout.mm
//  CustomListLayout-iOS
//
//  Created by Jinwoo Kim on 12/23/23.
//

#import "ListCollectionViewLayout.hpp"
#import <numeric>
#import <algorithm>

__attribute__((objc_direct_members))
@interface ListCollectionViewLayout () {
    CGSize _collectionViewContentSize;
}
@property (retain, nonatomic) NSMutableOrderedSet<UICollectionViewLayoutAttributes *> * _Nullable cachedAllAttributes;
@property (retain, nonatomic) NSMutableDictionary<NSNumber *, NSMutableOrderedSet<UICollectionViewLayoutAttributes *> *> * _Nullable cachedAllAttributesForSection;
@property (retain, nonatomic) NSMutableSet<UICollectionViewLayoutAttributes *> *invalidatedAllAttributes;
@end

@implementation ListCollectionViewLayout

+ (Class)invalidationContextClass {
    return UICollectionViewLayoutInvalidationContext.class;
}

- (instancetype)init {
    if (self = [super init]) {
        _invalidatedAllAttributes = [NSMutableSet<UICollectionViewLayoutAttributes *> new];
    }
    
    return self;
}

- (void)dealloc {
    [_cachedAllAttributes release];
    [_cachedAllAttributesForSection release];
    [_invalidatedAllAttributes release];
    [super dealloc];
}

- (CGSize)collectionViewContentSize {
    return _collectionViewContentSize;
}

- (void)prepareLayout {
    [super prepareLayout];
    
    if (_cachedAllAttributes && _cachedAllAttributesForSection) return;
    
    UICollectionView *collectionView = self.collectionView;
    
    if (!collectionView) {
        self.cachedAllAttributes = nil;
        self.cachedAllAttributesForSection = nil;
        return;
    }
    
    //
    
    NSInteger numberOfSections = collectionView.numberOfSections;
    if (numberOfSections == 0) return;
    
    std::vector<NSInteger> sectionIndexes(numberOfSections);
    std::iota(sectionIndexes.begin(), sectionIndexes.end(), 0);
    
    NSInteger numberOfItemsOfAllSections = std::accumulate(sectionIndexes.cbegin(),
                                                           sectionIndexes.cend(),
                                                           0,
                                                           [collectionView](NSInteger partial, NSInteger section) {
        NSInteger numberOfItems = [collectionView numberOfItemsInSection:section];
        return partial + numberOfItems;
    });
    
    auto cachedAllAttributes = [[NSMutableOrderedSet<UICollectionViewLayoutAttributes *> alloc] initWithCapacity:numberOfItemsOfAllSections];
    auto cachedAllAttributesForSection = [[NSMutableDictionary<NSNumber *, NSMutableOrderedSet<UICollectionViewLayoutAttributes *> *> alloc] initWithCapacity:numberOfSections];
    
    CGSize size = collectionView.bounds.size;
    CGFloat width = size.width;
    
    CGFloat totalHeight = std::accumulate(sectionIndexes.cbegin(),
                                          sectionIndexes.cend(),
                                          0.f,
                                          [collectionView, cachedAllAttributes, cachedAllAttributesForSection, width](CGFloat partialHeight, NSInteger section) {
        NSInteger numberOfItems = [collectionView numberOfItemsInSection:section];
        
        if (numberOfItems == 0) {
            return partialHeight;
        }
        
        auto cachedAttributesForSection = [[NSMutableOrderedSet<UICollectionViewLayoutAttributes *> alloc] initWithCapacity:numberOfItems];
        std::vector<NSInteger> itemIndexes(numberOfItems);
        std::iota(itemIndexes.begin(), itemIndexes.end(), 0);
        
        CGFloat height = std::accumulate(itemIndexes.cbegin(),
                                         itemIndexes.cend(),
                                         partialHeight,
                                         [section, cachedAllAttributes, cachedAttributesForSection, width](CGFloat partialHeight, NSInteger item) {
            NSAutoreleasePool *pool = [NSAutoreleasePool new];
            
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
            UICollectionViewLayoutAttributes *layoutAttributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
            
            layoutAttributes.frame = CGRectMake(0.f,
                                                partialHeight,
                                                width,
                                                44.f /* estimated */ );
            
            [cachedAllAttributes addObject:layoutAttributes];
            [cachedAttributesForSection addObject:layoutAttributes];
            
            [pool release];
            
            return partialHeight + 44.f; /* estimated */
        });
        
        cachedAllAttributesForSection[@(section)] = cachedAttributesForSection;
        [cachedAttributesForSection release];
        
        return height;
    });
    
    _collectionViewContentSize = CGSizeMake(size.width, totalHeight + collectionView.safeAreaInsets.bottom);
    self.cachedAllAttributes = cachedAllAttributes;
    self.cachedAllAttributesForSection = cachedAllAttributesForSection;
    
    [cachedAllAttributes release];
    [cachedAllAttributesForSection release];
}

- (void)prepareForCollectionViewUpdates:(NSArray<UICollectionViewUpdateItem *> *)updateItems {
    [super prepareForCollectionViewUpdates:updateItems];
    // TODO
    NSLog(@"%@", updateItems);
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<UICollectionViewLayoutAttributes *> *cachedAttributes = [_cachedAllAttributesForSection[@(indexPath.section)] array];
    NSInteger item = indexPath.item;
    
    if (cachedAttributes.count <= item) return nil;
    return cachedAttributes[item];
}

- (NSArray<__kindof UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    return [_cachedAllAttributes array];
}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)itemIndexPath {
    return [self layoutAttributesForItemAtIndexPath:itemIndexPath];
}

- (BOOL)shouldInvalidateLayoutForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes {
    BOOL result = !CGSizeEqualToSize(preferredAttributes.frame.size, originalAttributes.frame.size);
    
    if (result) {
        [_invalidatedAllAttributes addObject:preferredAttributes];
    }
    
    return result;
}

- (void)invalidateLayoutWithContext:(UICollectionViewLayoutInvalidationContext *)context {
    NSUInteger invalidatedCount = _invalidatedAllAttributes.count;
    
    if (invalidatedCount) {
        auto indexPaths = [[NSMutableArray<NSIndexPath *> alloc] initWithCapacity:invalidatedCount];
        NSUInteger count_cachedAllAttributes = _cachedAllAttributes.count;
        
        for (UICollectionViewLayoutAttributes *attributes in _invalidatedAllAttributes) {
            NSIndexPath *indexPath = attributes.indexPath;
            
            [indexPaths addObject:indexPath];
            
            //
            
            UICollectionViewLayoutAttributes *oldAttributes = [_cachedAllAttributesForSection[@(indexPath.section)] array][indexPath.item];
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
        [context invalidateItemsAtIndexPaths:indexPaths];
        [indexPaths release];
    }
}

@end
