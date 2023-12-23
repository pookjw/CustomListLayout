//
//  ListItemModel.h
//  CustomListLayout-iOS
//
//  Created by Jinwoo Kim on 12/23/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ListItemModel : NSObject
@property (copy, nonatomic, readonly) NSNumber *section;
@property (copy, nonatomic, readonly) NSNumber *item;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithSection:(NSNumber *)section item:(NSNumber *)item NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
