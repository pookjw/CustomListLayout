//
//  ListViewController.mm
//  CustomListLayout-iOS
//
//  Created by Jinwoo Kim on 12/22/23.
//

#import "ListViewController.hpp"
#import "ListViewModel.hpp"
#import "ListCollectionViewLayout.hpp"
#import <objc/message.h>

#define USE_CUSTOM_LAYOUT 1

__attribute__((objc_direct_members))
@interface ListViewController ()
@property (retain, readonly, nonatomic) UICollectionView *collectionView;
@property (retain, nonatomic) ListViewModel *viewModel;
@end

@implementation ListViewController
@synthesize collectionView = _collectionView;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        [self commonInit_ListViewController];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self commonInit_ListViewController];
    }
    
    return self;
}

- (void)commonInit_ListViewController __attribute__((objc_direct)) {
    UINavigationItem *navigationItem = self.navigationItem;
    navigationItem.title = @"ListListListListListListListListList";
    navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    
    reinterpret_cast<void (*)(id, SEL, long)>(objc_msgSend)(navigationItem, sel_registerName("_setLargeTitleTwoLineMode:"), 1);
    
    //
    
    __block auto unretained = self;
    
    UIAction *shuffleAction = [UIAction actionWithTitle:@"Shuffle"
                                                  image:[UIImage systemImageNamed:@"shuffle"]
                                             identifier:nil
                                                handler:^(__kindof UIAction * _Nonnull action) {
        [unretained.viewModel shuffleWithCompletionHandler:nil];
    }];
    
    UIAction *sortAction = [UIAction actionWithTitle:@"Sort"
                                               image:[UIImage systemImageNamed:@"arrow.clockwise"]
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull action) {
        [unretained.viewModel sortWithCompletionHandler:nil];
    }];
    
    UIAction *decrementAction = [UIAction actionWithTitle:@"Increment"
                                                    image:[UIImage systemImageNamed:@"minus"]
                                               identifier:nil
                                                  handler:^(__kindof UIAction * _Nonnull action) {
        [unretained.viewModel decrementWithCompletionHandler:nil];
    }];
    
    UIAction *incrementAction = [UIAction actionWithTitle:@"Increment"
                                                    image:[UIImage systemImageNamed:@"plus"]
                                               identifier:nil
                                                  handler:^(__kindof UIAction * _Nonnull action) {
        [unretained.viewModel incrementWithCompletionHandler:nil];
    }];
    
    UIMenu *orderMenu = [UIMenu menuWithTitle:@"Order"
                                        image:nil
                                   identifier:nil
                                      options:UIMenuOptionsDisplayInline
                                     children:@[
        shuffleAction,
        sortAction
    ]];
    
    UIMenu *dataMenu = [UIMenu menuWithTitle:@"Data"
                                       image:nil
                                  identifier:nil
                                     options:UIMenuOptionsDisplayInline
                                    children:@[
        decrementAction,
        incrementAction
    ]];
    
    orderMenu.preferredElementSize = UIMenuElementSizeMedium;
    dataMenu.preferredElementSize = UIMenuElementSizeMedium;
    
    UIDeferredMenuElement *scrollToRandomItemAction = [UIDeferredMenuElement elementWithUncachedProvider:^(void (^ _Nonnull completion)(NSArray<UIMenuElement *> * _Nonnull)) {
        // TODO: Display random index path
        UIAction *action = [UIAction actionWithTitle:[NSString stringWithFormat:@"%@", [NSDate now]]
                                               image:[UIImage systemImageNamed:@"arrow.up.arrow.down"]
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull action) {
            
        }];
        
        completion(@[action]);
    }];
    
    UIAction *reloadAction = [UIAction actionWithTitle:@"Reload"
                                                 image:[UIImage systemImageNamed:@"arrow.counterclockwise"]
                                            identifier:nil 
                                               handler:^(__kindof UIAction * _Nonnull action) {
        [unretained.viewModel reloadWithCompletionHandler:nil];
    }];
    
    UIMenu *menu = [UIMenu menuWithChildren:@[
        orderMenu,
        dataMenu,
        scrollToRandomItemAction,
        reloadAction
    ]];
    
    //
    
    UIButtonConfiguration *buttonConfiguration = [UIButtonConfiguration tintedButtonConfiguration];
    buttonConfiguration.image = [UIImage systemImageNamed:@"line.3.horizontal"];
    
    UIButton *accessoryButton = [UIButton buttonWithType:UIButtonTypeCustom];
    accessoryButton.showsMenuAsPrimaryAction = YES;
    accessoryButton.configuration = buttonConfiguration;
    accessoryButton.menu = menu;
    
    reinterpret_cast<void (*)(id, SEL, id)>(objc_msgSend)(navigationItem, sel_registerName("_setLargeTitleAccessoryView:"), accessoryButton);
    
    //
    
    UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal"]
                                                                       menu:menu];
    navigationItem.rightBarButtonItem = barButtonItem;
    [barButtonItem release];
}

- (void)dealloc {
    [_collectionView release];
    [_viewModel release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupAttributes];
    [self setupCollectionView];
    [self setupViewModel];
}

- (void)setupAttributes __attribute__((objc_direct)) {
    self.view.backgroundColor = UIColor.systemBackgroundColor;
}

- (void)setupCollectionView __attribute__((objc_direct)) {
    UICollectionView *collectionView = self.collectionView;
    collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:collectionView];
}

- (void)setupViewModel __attribute__((objc_direct)) {
    ListViewModel *viewModel = [[ListViewModel alloc] initWithDataSource:[self makeDataSource]];
    self.viewModel = viewModel;
    [viewModel loadDataSourceWithCompletionHandler:nil];
    [viewModel release];
}

- (UICollectionViewDiffableDataSource<NSNumber *, ListItemModel *> *)makeDataSource __attribute__((objc_direct)) {
    auto cellRegistration = [UICollectionViewCellRegistration registrationWithCellClass:UICollectionViewListCell.class configurationHandler:^(__kindof UICollectionViewListCell * _Nonnull cell, NSIndexPath * _Nonnull indexPath, ListItemModel * _Nonnull item) {
        auto contentConfiguration = [cell defaultContentConfiguration];
        contentConfiguration.text = [NSString stringWithFormat:@"-----\nSection: %@\nItem: %@\n-----", item.section, item.item];
        
        if (indexPath.item % 2) {
            contentConfiguration.text = [contentConfiguration.text stringByAppendingString:@"\nOdd\n-----"];
        }
        //        contentConfiguration.text = [NSString stringWithFormat:@"%@ - %@", item.section, item.item];
        
        contentConfiguration.textProperties.numberOfLines = 0;
        cell.contentConfiguration = contentConfiguration;
    }];
    
    auto dataSource = [[UICollectionViewDiffableDataSource<NSNumber *, ListItemModel *> alloc] initWithCollectionView:self.collectionView cellProvider:^UICollectionViewCell * _Nullable(UICollectionView * _Nonnull collectionView, NSIndexPath * _Nonnull indexPath, id  _Nonnull itemIdentifier) {
        return [collectionView dequeueConfiguredReusableCellWithRegistration:cellRegistration forIndexPath:indexPath item:itemIdentifier];
    }];
    
    return [dataSource autorelease];
}

- (UICollectionView *)collectionView {
    if (_collectionView) return _collectionView;
    
#if USE_CUSTOM_LAYOUT
    ListCollectionViewLayout *collectionViewLayout = [ListCollectionViewLayout new];
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:collectionViewLayout];
    [collectionViewLayout release];
#else
    UICollectionLayoutListConfiguration *listConfiguration = [[UICollectionLayoutListConfiguration alloc] initWithAppearance:UICollectionLayoutListAppearancePlain];
    UICollectionViewCompositionalLayout *collectionViewLayout = [UICollectionViewCompositionalLayout layoutWithListConfiguration:listConfiguration];
    [listConfiguration release];
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:collectionViewLayout];
#endif
    
    _collectionView = [collectionView retain];
    
    return [collectionView autorelease];
}

@end
