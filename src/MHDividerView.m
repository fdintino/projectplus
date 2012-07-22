//
//  MHDividerView.m
//  ProjectPlus
//
//  Created by Mark Huot on 5/24/11.
//  Copyright 2011 Home. All rights reserved.
//

#import "MHDividerView.h"


@implementation MHDividerView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }

    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor colorWithDeviceWhite:1.0 alpha:0.8] set];
    NSRectFillUsingOperation(NSMakeRect(0, 0, [self bounds].size.width, 1.0), NSCompositeSourceOver);

    [[NSColor colorWithDeviceWhite:0.0 alpha:0.2] set];
    NSRectFillUsingOperation(NSMakeRect(0, 1.0, [self bounds].size.width, 1.0), NSCompositeSourceOver);
}

@end
