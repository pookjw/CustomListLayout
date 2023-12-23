//
//  ListItemModel.mm
//  CustomListLayout-iOS
//
//  Created by Jinwoo Kim on 12/23/23.
//

#import "ListItemModel.hpp"

@implementation ListItemModel

- (instancetype)initWithSection:(NSNumber *)section item:(NSNumber *)item {
    if (self = [super init]) {
        _section = [section copy];
        _item = [item copy];
    }
    
    return self;
}

- (void)dealloc {
    [_section release];
    [_item release];
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    } else if (![super isEqual:other]) {
        return NO;
    } else {
        auto _other = reinterpret_cast<decltype(self)>(other);
        
        return [_section isEqualToNumber:_other->_section] && [_item isEqualToNumber:_other->_item];
    }
}

- (NSUInteger)hash {
    return _section.hash ^ _item.hash;
}

@end
