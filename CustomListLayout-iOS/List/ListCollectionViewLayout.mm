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
@property (copy) NSOrderedSet<UICollectionViewLayoutAttributes *> * _Nullable cachedAllAttributes;
@end

@implementation ListCollectionViewLayout

- (void)dealloc {
    [_cachedAllAttributes release];
    [super dealloc];
}

- (CGSize)collectionViewContentSize {
    return _collectionViewContentSize;
}

- (void)prepareLayout {
    [super prepareLayout];
    
    UICollectionView *collectionView = self.collectionView;
    
    if (!collectionView) {
        self.cachedAllAttributes = nil;
        return;
    }
    
    //
    
    CGSize size = collectionView.bounds.size;
    CGFloat halfWidth = size.width * 0.5f;
    NSInteger numberOfSections = collectionView.numberOfSections;
    
    std::vector<NSInteger> sectionIndexes(numberOfSections);
    std::iota(sectionIndexes.begin(), sectionIndexes.end(), 0);
    
    
    NSInteger numberOfItemsOfAllSections = std::accumulate(sectionIndexes.cbegin(),
                                                           sectionIndexes.cend(),
                                                           0,
                                                           [collectionView](NSInteger partial, NSInteger section) {
        return partial + [collectionView numberOfItemsInSection:section];
    });
    
    auto cachedAllAttributes = [[NSMutableOrderedSet<UICollectionViewLayoutAttributes *> alloc] initWithCapacity:numberOfItemsOfAllSections];
    
    CGFloat totalHeight = std::accumulate(sectionIndexes.cbegin(),
                                          sectionIndexes.cend(),
                                          0.f,
                                          [collectionView, halfWidth, cachedAllAttributes](CGFloat partialHeight, NSInteger section) {
        NSInteger numberOfItems = [collectionView numberOfItemsInSection:section];
        
        if (numberOfItems == 0) {
            return partialHeight;
        }
        
        std::vector<NSInteger> itemIndexes(numberOfItems);
        std::iota(itemIndexes.begin(), itemIndexes.end(), 0);
        
        CGFloat height = std::accumulate(itemIndexes.cbegin(),
                                         itemIndexes.cend(),
                                         partialHeight,
                                         [section, halfWidth, cachedAllAttributes](CGFloat partialHeight, NSInteger item) {
            NSAutoreleasePool *pool = [NSAutoreleasePool new];
            
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
            UICollectionViewLayoutAttributes *layoutAttributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
            BOOL isEven = item % 2 == 0;
            
            layoutAttributes.frame = CGRectMake(isEven ? 0.f : halfWidth,
                                                partialHeight,
                                                halfWidth,
                                                44.f /* estimated */ );
            
            [cachedAllAttributes addObject:layoutAttributes];
            
            if (!isEven) {
                partialHeight += 44.f;
            }
            
            [pool release];
            
            return partialHeight;
        });
        
        return height;
    });
    
    _collectionViewContentSize = CGSizeMake(size.width, totalHeight + collectionView.safeAreaInsets.bottom);
    self.cachedAllAttributes = cachedAllAttributes;
    [cachedAllAttributes release];
}

- (void)prepareForCollectionViewUpdates:(NSArray<UICollectionViewUpdateItem *> *)updateItems {
    
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (NSArray<__kindof UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    return [_cachedAllAttributes array];
}

@end
